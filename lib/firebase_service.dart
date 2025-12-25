import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';
import 'lib/models/event.dart'; // 正規のEventモデル
import 'lib/services/firebase_service_error.dart';
import 'lib/lib/models/team_progress.dart';
import 'lib/models/escape_record.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() => _instance;

  FirebaseService._internal() {
    _init();
  }

  // MARK: - Properties
  final Uuid _uuid = const Uuid();
  late FirebaseStorage _storage;
  late FirebaseDatabase _database;

  final String _storageBucketURL = "gs://dassyutsu2.firebasestorage.app";
  final String _databaseURL = "https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app";

  // Firebaseが初期化されているか
  bool get isConfigured => Firebase.apps.isNotEmpty;

  // MARK: - Firebase Database Path Encoding
  
  /// Firebase Realtime Databaseのパスとして使用するために、teamIdをエンコードする
  /// 無効な文字（. # $ [ ]）を安全な文字に置換する
  String _encodeTeamIdForPath(String teamId) {
    return teamId
        .replaceAll('.', '_DOT_')
        .replaceAll('#', '_HASH_')
        .replaceAll('\$', '_DOLLAR_')
        .replaceAll('[', '_LBRACKET_')
        .replaceAll(']', '_RBRACKET_');
  }
  
  /// エンコードされたteamIdをデコードする
  String _decodeTeamIdFromPath(String encodedTeamId) {
    return encodedTeamId
        .replaceAll('_DOT_', '.')
        .replaceAll('_HASH_', '#')
        .replaceAll('_DOLLAR_', '\$')
        .replaceAll('_LBRACKET_', '[')
        .replaceAll('_RBRACKET_', ']');
  }

  // MARK: - Initialization
  void _init() {
    if (isConfigured) {
      // Dartでは、アプリ起動時にFirebase.initializeApp()を呼び出す必要がある。
      // ここでは、既に初期化されていることを前提とする。
      _storage = FirebaseStorage.instanceFor(bucket: _storageBucketURL);
      _database = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _databaseURL);
      debugPrint("✅ [FirebaseService] Storage Bucket: $_storageBucketURL");
      debugPrint("✅ [FirebaseService] Realtime Database URL: $_databaseURL");
      debugPrint("🔍 [FirebaseService] Database Instance URL: ${_database.databaseURL}");
      debugPrint("🔍 [FirebaseService] Firebase App Name: ${Firebase.app().name}");
      debugPrint("🔍 [FirebaseService] Firebase App Project ID: ${Firebase.app().options.projectId}");
      debugPrint("🔍 [FirebaseService] Firebase App API Key: ${Firebase.app().options.apiKey.substring(0, 10)}...");
    } else {
      debugPrint("⚠️ [FirebaseService] Firebaseが初期化されていません。Firebase機能は使用できません。");
    }
  }

  // MARK: - Storage: 画像圧縮
  
  /// 画像を圧縮（リサイズ＋JPEG圧縮）
  Future<Uint8List> _compressImage(File imageFile, {double maxDimension = 1920, int quality = 70}) async {
    final bytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      throw FirebaseServiceError('画像のデコードに失敗しました');
    }

    final double aspectRatio = originalImage.width / originalImage.height;
    int newWidth = originalImage.width;
    int newHeight = originalImage.height;

    // リサイズが必要かチェック
    if (originalImage.width > maxDimension || originalImage.height > maxDimension) {
      if (originalImage.width > originalImage.height) {
        newWidth = maxDimension.toInt();
        newHeight = (maxDimension / aspectRatio).round();
      } else {
        newHeight = maxDimension.toInt();
        newWidth = (maxDimension * aspectRatio).round();
      }
      
      originalImage = img.copyResize(originalImage, width: newWidth, height: newHeight);
    }
    
    // JPEG圧縮
    final compressedData = img.encodeJpg(originalImage, quality: quality);
    return Uint8List.fromList(compressedData);
  }

  // MARK: - Storage: 画像アップロード
  
  /// 画像をFirebase Storageにアップロード
  Future<String> uploadImage(File imageFile, String teamId, String eventId, int problemIndex) async {
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      // 画像を圧縮（最大1920px、JPEG品質70）
      final imageData = await _compressImage(imageFile, maxDimension: 1920, quality: 70);
      
      final fileName = "check_images/$teamId/$eventId/problem_${problemIndex}_${_uuid.v4()}.jpg";
      final Reference ref = _storage.ref().child(fileName);
      
      // アップロード
      final UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: "image/jpeg"));
      final TaskSnapshot snapshot = await uploadTask;
      
      // ダウンロードURLを取得
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("❌ [FirebaseService] 画像アップロード失敗: $e");
      throw FirebaseServiceError('画像アップロードに失敗しました', code: 'upload-failed');
    }
  }
  // MARK: - Storage: 見本画像アップロード (ProblemEditViewで使用) 👈 このセクションとして追記
  
/// 問題の見本画像（チェック画像）をFirebase Storageにアップロード
Future<String> uploadReferenceImage(File imageFile, String eventId, String problemId) async {
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      // 画像を圧縮（既存の _compressImage を利用）
      final imageData = await _compressImage(imageFile, maxDimension: 1920, quality: 70);
      
      // パスを「reference_images/{eventId}/{problemId}/...」で整理
      final fileName = "reference_images/$eventId/$problemId/ref_image_${_uuid.v4()}.jpg";
      final Reference ref = _storage.ref().child(fileName);
      
      // アップロード
      final UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: "image/jpeg"));
      final TaskSnapshot snapshot = await uploadTask;
      
      // ダウンロードURLを取得
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("❌ [FirebaseService] 見本画像アップロード失敗: $e");
      throw FirebaseServiceError('見本画像アップロードに失敗しました', code: 'upload-failed');
    }
}

  // MARK: - Storage: イベントカード画像アップロード (EventTitleEditViewで使用)
  
  /// イベントカード画像をFirebase Storageにアップロード
  Future<String> uploadEventCardImage(File imageFile, {String? eventId}) async {
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      // 画像を圧縮（最大1920px、JPEG品質85）
      final imageData = await _compressImage(imageFile, maxDimension: 1920, quality: 85);
      
      // パスを「event_cards/{eventId}/card_image_{uuid}.jpg」で整理
      final eventIdPath = eventId?.isNotEmpty == true ? "$eventId/" : "";
      final fileName = "event_cards/$eventIdPath${_uuid.v4()}.jpg";
      final Reference ref = _storage.ref().child(fileName);
      
      // アップロード
      final UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: "image/jpeg"));
      final TaskSnapshot snapshot = await uploadTask;
      
      // ダウンロードURLを取得
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint("✅ [FirebaseService] イベントカード画像アップロード成功: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      debugPrint("❌ [FirebaseService] イベントカード画像アップロード失敗: $e");
      throw FirebaseServiceError('イベントカード画像アップロードに失敗しました', code: 'upload-failed');
    }
  }

  // MARK: - Storage: 動画アップロード
  
  /// 動画を圧縮してアップロード (動画圧縮は video_compress パッケージを利用)
  Future<String> uploadMediaVideo(File videoFile, String eventId, String problemId) async {
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      debugPrint("🎬 [FirebaseService] 動画圧縮を開始: ${videoFile.path}");

      // video_compress を使用して圧縮（1280x720相当、AVAssetExportPresetMediumQualityに近い設定）
      final MediaInfo? compressedMedia = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        frameRate: 30, // フレームレートを制限
      );
      
      if (compressedMedia == null || compressedMedia.path == null) {
        throw FirebaseServiceError('動画圧縮に失敗しました', code: 'compression-failed');
      }

      final compressedFile = File(compressedMedia.path!);
      final fileName = "$eventId/media/${problemId}_${_uuid.v4()}.mp4";
      final Reference ref = _storage.ref().child(fileName);

      // アップロード
      final UploadTask uploadTask = ref.putFile(compressedFile, SettableMetadata(contentType: "video/mp4"));
      final TaskSnapshot snapshot = await uploadTask;
      
      // 一時ファイルを削除
      try {
         await compressedFile.delete();
      } catch (e) {
         debugPrint("⚠️ [FirebaseService] 圧縮後の一時ファイル削除失敗: $e");
      }

      // ダウンロードURLを取得
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint("❌ [FirebaseService] 動画アップロード失敗: $e");
      throw FirebaseServiceError('動画アップロードに失敗しました', code: 'upload-failed');
    }
  }


  // MARK: - Realtime Database: 進捗管理
  
  /// チームの進捗を取得
  Future<TeamProgress?> getTeamProgress(String teamId, String eventId) async {
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

    final encodedTeamId = _encodeTeamIdForPath(teamId);
    final ref = _database.ref().child("team_progress/$encodedTeamId/$eventId");
    try {
      final snapshot = await ref.get();
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }
      
      final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
      return TeamProgress.fromJson(data);
    } catch (e) {
      debugPrint("❌ [FirebaseService] 進捗データの取得に失敗: $e");
      throw FirebaseServiceError.fromFirebaseDatabaseError(e);
    }
  }
  
  /// チームの進捗をリアルタイム監視 (Streamを使用)
  Stream<TeamProgress?> observeTeamProgress(String teamId, String eventId) {
    if (!isConfigured) {
      debugPrint("⚠️ [FirebaseService] Firebaseが初期化されていません。監視を開始できません。");
      return Stream.value(null);
    }
    
    final encodedTeamId = _encodeTeamIdForPath(teamId);
    final ref = _database.ref().child("team_progress/$encodedTeamId/$eventId");
    
    return ref.onValue.map((event) {
      final snapshot = event.snapshot;
      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(snapshot.value as Map);
        return TeamProgress.fromJson(data);
      } catch (e) {
        debugPrint("⚠️ [FirebaseService] 進捗データのデコードに失敗: $e");
        return null;
      }
    });
    // DartのStreamはリスナーがいなくなると自動で閉じられるため、明示的なremoveObserverは通常不要
  }
  // MARK: - Realtime Database: チーム/プレイヤー管理 👈 このセクションとして追記

/// チーム名（プレイヤー名）の重複をチェック
/// パス: teams/{eventId}/{normalizedTeamName} を想定
/// 正規化されたチーム名（小文字、トリム済み）をキーとして使用
Future<bool> checkPlayerNameDuplicate(String teamName, String eventId) async {
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

  // チーム名は小文字にしてチェックすることが一般的です
  final normalizedTeamName = teamName.toLowerCase().trim();
  
  if (normalizedTeamName.isEmpty) {
    debugPrint("⚠️ [FirebaseService] 正規化後のチーム名が空です");
    return false; // 空の名前は重複として扱わない
  }
  
  // Realtime Databaseのパスを設定
  // teams/{eventId}/{normalizedTeamName} の構造を想定
  final ref = _database.ref().child("teams/$eventId/$normalizedTeamName");

  try {
    // 指定されたパスにデータが存在するかチェック
    final snapshot = await ref.get();
    
    // スナップショットにデータが存在すれば重複している
    final bool isDuplicate = snapshot.exists && snapshot.value != null;
    
    debugPrint("🔍 [FirebaseService] チーム名 '$teamName' (正規化: '$normalizedTeamName') の重複チェック: $isDuplicate");
    if (isDuplicate) {
      debugPrint("   - パス: teams/$eventId/$normalizedTeamName");
    }
    return isDuplicate;
  } catch (e) {
    debugPrint("❌ [FirebaseService] チーム名チェック失敗: $e");
    throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  }
}

/// プレイヤー名（チーム名）をFirebase Realtime Databaseに登録
/// パス: teams/{eventId}/{normalizedTeamName} に保存
/// 値: { "originalName": 元の名前, "registeredAt": 登録日時, "teamId": チームID }
Future<void> registerPlayerName(String teamName, String eventId, String teamId) async {
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

  // チーム名を正規化（小文字、トリム）
  final normalizedTeamName = teamName.toLowerCase().trim();
  
  if (normalizedTeamName.isEmpty) {
    throw FirebaseServiceError('チーム名が空です');
  }
  
  // 重複チェック
  final isDuplicate = await checkPlayerNameDuplicate(teamName, eventId);
  if (isDuplicate) {
    throw FirebaseServiceError('この名前は既に登録されています');
  }
  
  // Realtime Databaseのパスを設定
  final ref = _database.ref().child("teams/$eventId/$normalizedTeamName");

  try {
    // プレイヤー名情報を保存
    final data = {
      "originalName": teamName.trim(), // 元の名前（大文字小文字を保持）
      "normalizedName": normalizedTeamName, // 正規化された名前
      "teamId": teamId, // チームID（デバイスID）
      "registeredAt": DateTime.now().toIso8601String(), // 登録日時
    };
    
    await ref.set(data);
    debugPrint("✅ [FirebaseService] プレイヤー名を登録しました: '$teamName' (正規化: '$normalizedTeamName')");
    debugPrint("   - パス: teams/$eventId/$normalizedTeamName");
    debugPrint("   - チームID: $teamId");
  } catch (e) {
    debugPrint("❌ [FirebaseService] プレイヤー名の登録に失敗: $e");
    throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  }
}
  /// チームの進捗を更新/新規作成
  Future<void> updateTeamProgress(TeamProgress progress) async {
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

    // Realtime Databaseのパス: team_progress/{teamId}/{eventId}
    final encodedTeamId = _encodeTeamIdForPath(progress.teamId);
    final ref = _database.ref().child("team_progress/$encodedTeamId/${progress.eventId}");
    
    try {
      // TeamProgressオブジェクトをMapに変換してデータベースに書き込む
      await ref.set(progress.toJson());
      debugPrint("✅ [FirebaseService] 進捗データ更新成功: ${progress.teamId}/${progress.eventId}");
    } catch (e) {
      debugPrint("❌ [FirebaseService] 進捗データの更新に失敗: $e");
      // FirebaseDatabaseErrorからカスタムエラーに変換してスロー
      throw FirebaseServiceError.fromFirebaseDatabaseError(e);
    }
  }
  // MARK: - Realtime Database: 脱出記録 (追記)

  /// 脱出記録をFirebase Realtime Databaseに保存
  /// パス: escape_records/{eventId}/{recordId} と events/{eventId}/records/{recordId} の両方に保存
  Future<void> addEscapeRecord(EscapeRecord record, {required String eventId}) async {
    // ⚠️ 注意: EscapeRecordとEventモデルの定義が別途必要です
    
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

    try {
      // 1. escape_records/{eventId}/{recordId}に保存（メインの保存先）
      final escapeRecordsRef = _database.ref().child("escape_records/$eventId/${record.id}");
      await escapeRecordsRef.set(record.toJson());
      debugPrint("✅ [FirebaseService] 脱出記録をescape_recordsに保存: $eventId/${record.id}");
      
      // 2. events/{eventId}/records/{recordId}にも保存（イベントオブジェクト内のrecordsにも反映）
      final eventRecordsRef = _database.ref().child("events/$eventId/records/${record.id}");
      await eventRecordsRef.set(record.toJson());
      debugPrint("✅ [FirebaseService] 脱出記録をevents/recordsに保存: $eventId/${record.id}");
      
      debugPrint("✅ [FirebaseService] 脱出記録保存成功: $eventId/${record.id}");
    } catch (e) {
      debugPrint("❌ [FirebaseService] 脱出記録の保存に失敗: $e");
      throw FirebaseServiceError.fromFirebaseDatabaseError(e);
    }
  }
  // MARK: - Realtime Database: 暗証番号認証とイベント作成管理

  /// イベント作成数をインクリメント（トランザクション処理）
  Future<int> incrementEventsCreated(String passcode) async {
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
    
    final ref = _database.ref().child("passcodes/ADMIN_CREATE_PASSCODES/$passcode/events_created");
    const int maxEvents = 5;

    try {
      final result = await ref.runTransaction((currentValue) {
        int value = currentValue as int? ?? 0;
        
        // 上限チェック
        if (value >= maxEvents) {
          throw FirebaseServiceError('イベント作成の上限 (5件) に達しています', code: 'event-limit-exceeded');
        }
        
        value += 1;
        return Transaction.success(value);
      });

      return result.snapshot.value as int? ?? 0;
    } catch (e) {
      debugPrint("❌ [FirebaseService] トランザクションエラー: $e");
      throw FirebaseServiceError.fromFirebaseDatabaseError(e);
    }
  }
  
  // MARK: - Realtime Database: イベントデータ

  /// すべてのイベントを取得
  Future<List<Event>> getAllEvents() async {
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
    
    final ref = _database.ref().child("events");
    debugPrint("📡 [FirebaseService] Firebase Realtime Databaseからイベントを取得: events/");
    debugPrint("📡 [FirebaseService] Database URL: $_databaseURL");
    debugPrint("📡 [FirebaseService] Firebase Apps: ${Firebase.apps.length}");
    
    try {
      // データベース接続情報をログ出力
      debugPrint("🔍 [FirebaseService] データベース接続情報:");
      debugPrint("   - 参照パス: events/");
      debugPrint("   - データベースURL: ${_database.databaseURL}");
      debugPrint("   - Firebase App Name: ${Firebase.app().name}");
      debugPrint("   - Firebase App Project ID: ${Firebase.app().options.projectId}");
      
      // 認証状態を確認（ログ出力のみ）
      try {
        final auth = FirebaseAuth.instance;
        final currentUser = auth.currentUser;
        if (currentUser != null) {
          debugPrint("   - 認証ユーザー: ${currentUser.uid} (匿名: ${currentUser.isAnonymous})");
        } else {
          debugPrint("   - 認証状態: 未認証（eventsパスは公開読み取り許可されているため問題ありません）");
        }
      } catch (authError) {
        debugPrint("   - 認証状態の確認に失敗: $authError（続行します）");
      }
      
      debugPrint("🔍 [FirebaseService] eventsパスへのアクセスを試みます...");
      // タイムアウトを設定して接続を試みる
      final snapshot = await ref.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw FirebaseServiceError('データベース接続がタイムアウトしました');
        },
      );
      
      if (!snapshot.exists || snapshot.value == null) {
        debugPrint("⚠️ [FirebaseService] イベントデータが存在しません");
        return [];
      }
      
      // Dartでは Map<dynamic, dynamic> として取得されるため、型変換が必要
      final Map<String, dynamic> eventsDict = Map<String, dynamic>.from(snapshot.value as Map);
      
      List<Event> events = [];
      for (final entry in eventsDict.entries) {
        final eventId = entry.key;
        final eventData = entry.value;
        
        try {
          // Event.fromJson を使ってパースを試みる
          final event = Event.fromJson(Map<String, dynamic>.from(eventData as Map));
          
          // events/{eventId}/recordsが存在するかチェック
          final eventDataMap = Map<String, dynamic>.from(eventData as Map);
          final recordsData = eventDataMap['records'];
          final hasRecordsField = recordsData != null;
          
          // escape_records/{eventId}からもレコードを取得してマージ
          // リセット後の新しいレコードも含めて取得するため、常にescape_recordsから取得を試みる
          // ただし、event.recordsが空で、かつescape_recordsも存在しない場合は何もしない
          try {
            final escapeRecordsRef = _database.ref().child("escape_records/$eventId");
            final escapeRecordsSnapshot = await escapeRecordsRef.get();
            
            if (escapeRecordsSnapshot.exists && escapeRecordsSnapshot.value != null) {
              final escapeRecordsData = escapeRecordsSnapshot.value as Map;
              final List<EscapeRecord> escapeRecords = [];
              
              escapeRecordsData.forEach((recordId, recordData) {
                try {
                  if (recordData is Map) {
                    final recordMap = Map<String, dynamic>.from(recordData);
                    recordMap['id'] = recordId; // キーをIDとして使用
                    escapeRecords.add(EscapeRecord.fromJson(recordMap));
                  }
                } catch (e) {
                  debugPrint("⚠️ [FirebaseService] escape_recordsのレコードパースエラー (ID: $recordId): $e");
                }
              });
              
              if (escapeRecords.isNotEmpty) {
                // 既存のrecordsとescape_recordsをマージ（重複を避ける）
                final existingRecordIds = event.records.map((r) => r.id).toSet();
                final newRecords = escapeRecords.where((r) => !existingRecordIds.contains(r.id)).toList();
                
                if (newRecords.isNotEmpty) {
                  debugPrint("✅ [FirebaseService] escape_recordsから${newRecords.length}件のレコードを取得してマージ: $eventId");
                  // 既存のrecordsと新しいrecordsを結合
                  final mergedRecords = [...event.records, ...newRecords];
                  // Eventオブジェクトを更新（recordsをマージしたものに置き換え）
                  final updatedEvent = event.copyWith(records: mergedRecords);
                  events.add(updatedEvent);
                } else {
                  // escape_recordsに新しいレコードがない場合は、event.recordsを使用
                  // ただし、event.recordsが空で、escape_recordsも空の場合は、リセット済みと判断
                  if (event.records.isEmpty) {
                    debugPrint("ℹ️ [FirebaseService] event.recordsが空で、escape_recordsも空のため、リセット済みと判断: $eventId");
                  }
                  events.add(event);
                }
              } else {
                // escape_recordsが空の場合は、event.recordsを使用
                // リセット直後は、event.recordsも空、escape_recordsも存在しない状態
                if (event.records.isEmpty) {
                  debugPrint("ℹ️ [FirebaseService] event.recordsが空で、escape_recordsも存在しないため、リセット済みと判断: $eventId");
                }
                events.add(event);
              }
            } else {
              // escape_recordsが存在しない場合は、event.recordsを使用
              events.add(event);
            }
          } catch (e) {
            debugPrint("⚠️ [FirebaseService] escape_recordsの取得エラー (eventId: $eventId): $e");
            // escape_recordsの取得に失敗しても、イベント自体は追加する
            events.add(event);
          }
        } catch (e) {
          debugPrint("❌ [FirebaseService] イベントパース失敗 (ID: $eventId): $e");
        }
      }

      debugPrint("✅ [FirebaseService] パース完了: ${events.length}件のイベントを取得");
      return events;
    } catch (e) {
      debugPrint("❌ [FirebaseService] Firebase読み込みエラー: $e");
      
      // 権限エラーの場合、より詳細な情報を提供
      if (e.toString().contains('permission-denied')) {
        debugPrint("⚠️ [FirebaseService] セキュリティルールの確認が必要です");
        debugPrint("   現在のデータベースURL: $_databaseURL");
        debugPrint("   接続先データベース: ${_database.databaseURL}");
        debugPrint("   ⚠️ 重要: すべての読み書きを許可するルールでもエラーが発生しています");
        debugPrint("   考えられる原因:");
        debugPrint("   1. データベースインスタンスが複数ある可能性");
        debugPrint("   2. ルールが正しく公開されていない");
        debugPrint("   3. 異なるリージョンのデータベースに接続している");
        debugPrint("   4. Firebase Consoleで設定したルールが別のデータベースのもの");
        debugPrint("");
        debugPrint("   確認手順:");
        debugPrint("   1. Firebase Console → Realtime Database");
        debugPrint("   2. データベースインスタンスの一覧を確認");
        debugPrint("   3. URLが 'asia-southeast1' のインスタンスのルールを確認");
        debugPrint("   4. 「ルール」タブで現在のルールを確認");
        debugPrint("   5. 「公開」ボタンを再度クリック");
      }
      
      throw FirebaseServiceError.fromFirebaseDatabaseError(e);
    }
  }
  // MARK: - Realtime Database: イベント/問題データ 👈 このセクションとして追記

/// イベントを保存または更新する（問題データを含む）
Future<void> saveEvent(Event event) async {
  // ⚠️ 注意: EventモデルにはList<Problem>が含まれている必要があります
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
  
  final ref = _database.ref().child("events/${event.id}");
  
  try {
    // Eventオブジェクト（内部にProblemリストを含む）をMapに変換して書き込む
    await ref.set(event.toJson());
    debugPrint("✅ [FirebaseService] イベントデータ保存成功: ${event.id}");
  } catch (e) {
    debugPrint("❌ [FirebaseService] イベントデータの保存に失敗: $e");
    throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  }
}

/// イベントを削除する
Future<void> deleteEvent(String eventId) async {
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
  
  final ref = _database.ref().child("events/$eventId");
  
  try {
    await ref.remove();
    debugPrint("✅ [FirebaseService] イベントデータ削除成功: $eventId");
  } catch (e) {
    debugPrint("❌ [FirebaseService] イベントデータの削除に失敗: $e");
    throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  }
}

/// イベントのランキング（escape_records）を削除する
Future<void> deleteEscapeRecords(String eventId) async {
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
  
  final escapeRecordsRef = _database.ref().child("escape_records/$eventId");
  
  try {
    await escapeRecordsRef.remove();
    debugPrint("✅ [FirebaseService] escape_records削除成功: $eventId");
  } catch (e) {
    debugPrint("❌ [FirebaseService] escape_recordsの削除に失敗: $e");
    throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  }
}

/// イベントのランキング（events/{eventId}/records）を削除する
Future<void> deleteEventRecords(String eventId) async {
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
  
  final recordsRef = _database.ref().child("events/$eventId/records");
  
  try {
    await recordsRef.remove();
    debugPrint("✅ [FirebaseService] events/records削除成功: $eventId");
  } catch (e) {
    debugPrint("❌ [FirebaseService] events/recordsの削除に失敗: $e");
    throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  }
}
  // MARK: - Realtime Database: ユーザー/デバイス情報 (追記)
  
  /// ユーザーの端末情報をFirebase Realtime Databaseに保存/更新
  /// パス: device_info/{deviceId}
  // Future<void> saveUserDeviceInfo(UserDeviceInfo info) async {
  //   // ⚠️ 注意: UserDeviceInfoモデルの定義が別途必要です
    
  //   if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

  //   // Realtime Databaseのパスを作成。deviceIdを一意のキーとする
  //   final ref = _database.ref().child("device_info/${info.deviceId}");
    
  //   try {
  //     // UserDeviceInfoオブジェクトをMapに変換してデータベースに書き込む
  //     await ref.set(info.toJson());
  //     debugPrint("✅ [FirebaseService] デバイス情報保存成功: ${info.deviceId}");
  //   } catch (e) {
  //     debugPrint("❌ [FirebaseService] デバイス情報の保存に失敗: $e");
  //     throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  //   }
  // }
}