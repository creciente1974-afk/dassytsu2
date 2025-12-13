import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';
import 'models.dart'; // 定義したデータモデルをインポート
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

  final String _storageBucketURL = "gs://dassyutsu2025.firebasestorage.app";
  final String _databaseURL = "https://dassyutsu2025-default-rtdb.firebaseio.com/";

  // Firebaseが初期化されているか
  bool get isConfigured => Firebase.apps.isNotEmpty;

  // MARK: - Initialization
  void _init() {
    if (isConfigured) {
      // Dartでは、アプリ起動時にFirebase.initializeApp()を呼び出す必要がある。
      // ここでは、既に初期化されていることを前提とする。
      _storage = FirebaseStorage.instanceFor(bucket: _storageBucketURL);
      _database = FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: _databaseURL);
      debugPrint("✅ [FirebaseService] Storage Bucket: $_storageBucketURL");
      debugPrint("✅ [FirebaseService] Realtime Database URL: $_databaseURL");
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

    final ref = _database.ref().child("team_progress/$teamId/$eventId");
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
    
    final ref = _database.ref().child("team_progress/$teamId/$eventId");
    
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
/// パス: teams/{eventId}/{teamName} を想定
Future<bool> checkPlayerNameDuplicate(String teamName, String eventId) async {
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

  // チーム名は小文字にしてチェックすることが一般的です
  final normalizedTeamName = teamName.toLowerCase().trim();
  
  // Realtime Databaseのパスを設定
  final ref = _database.ref().child("teams/$eventId");

  try {
    // データベースから正規化されたチーム名と一致するキーを検索
    final snapshot = await ref.orderByKey().equalTo(normalizedTeamName).get();
    
    // スナップショットにデータが存在すれば重複している
    final bool isDuplicate = snapshot.exists && snapshot.value != null;
    
    debugPrint("🔍 [FirebaseService] チーム名 '$teamName' の重複チェック: $isDuplicate");
    return isDuplicate;
  } catch (e) {
    debugPrint("❌ [FirebaseService] チーム名チェック失敗: $e");
    throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  }
}
  /// チームの進捗を更新/新規作成
  Future<void> updateTeamProgress(TeamProgress progress) async {
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

    // Realtime Databaseのパス: team_progress/{teamId}/{eventId}
    final ref = _database.ref().child("team_progress/${progress.teamId}/${progress.eventId}");
    
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
  /// パス: escape_records/{eventId}/{recordId}
  Future<void> addEscapeRecord(EscapeRecord record, {required String eventId}) async {
    // ⚠️ 注意: EscapeRecordとEventモデルの定義が別途必要です
    
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

    // Realtime Databaseのパスを作成
    final ref = _database.ref().child("escape_records/$eventId/${record.id}");
    
    try {
      // EscapeRecordオブジェクトをMapに変換してデータベースに書き込む
      await ref.set(record.toJson());
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
        return value;
      });

      return result;
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
    
    try {
      final snapshot = await ref.get();
      
      if (!snapshot.exists || snapshot.value == null) {
        debugPrint("⚠️ [FirebaseService] イベントデータが存在しません");
        return [];
      }
      
      // Dartでは Map<dynamic, dynamic> として取得されるため、型変換が必要
      final Map<String, dynamic> eventsDict = Map<String, dynamic>.from(snapshot.value as Map);
      
      List<Event> events = [];
      eventsDict.forEach((eventId, eventData) {
        try {
          // Event.fromJson を使ってパースを試みる
          final event = Event.fromJson(Map<String, dynamic>.from(eventData as Map));
          events.add(event);
        } catch (e) {
          debugPrint("❌ [FirebaseService] イベントパース失敗 (ID: $eventId): $e");
        }
      });

      debugPrint("✅ [FirebaseService] パース完了: ${events.length}件のイベントを取得");
      return events;
    } catch (e) {
      debugPrint("❌ [FirebaseService] Firebase読み込みエラー: $e");
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