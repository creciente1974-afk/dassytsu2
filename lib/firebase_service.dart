import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';
import 'lib/models/event.dart'; // 正規のEventモデル
import 'lib/services/firebase_service_error.dart';
import 'lib/lib/models/team_progress.dart';
import 'lib/models/escape_record.dart'; // EscapeRecordモデル
import 'lib/models/user_device_info.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() => _instance;

  FirebaseService._internal() {
    // 初期化は使用時に遅延実行（lazy initialization）
    // コンストラクタでは何もしない
  }

  // MARK: - Properties
  final Uuid _uuid = const Uuid();
  FirebaseStorage? _storage;
  FirebaseDatabase? _database;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _initializationFailed = false; // 初期化失敗フラグ
  bool _isInitializing = false; // 初期化中フラグ
  Future<void>? _initializationFuture; // 初期化のFutureを保持

  final String _storageBucketURL = "gs://dassyutsu2.firebasestorage.app";
  final String _databaseURL = "https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app/";

  // Firebaseが初期化されているか
  bool get isConfigured => Firebase.apps.isNotEmpty && !_initializationFailed && _storage != null && _database != null;

  // MARK: - Initialization
  Future<void> _initAsync() async {
    if (_isInitializing) {
      debugPrint("🔄 [FirebaseService] 既に初期化中です");
      // 初期化が完了するまで待つ
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }
    
    if (isConfigured) {
      debugPrint("✅ [FirebaseService] 既に初期化済みです");
      return;
    }
    
    _isInitializing = true;
    debugPrint("🔄 [FirebaseService] _initAsync() 開始");
    
    try {
      // Firebaseの初期化を待つ（最大10秒）
      int retryCount = 0;
      const maxRetries = 100; // 10秒間待機（100ms × 100回）
      
      while (Firebase.apps.isEmpty && retryCount < maxRetries) {
        await Future.delayed(const Duration(milliseconds: 100));
        retryCount++;
      }
      
      if (Firebase.apps.isEmpty) {
        debugPrint("⚠️ [FirebaseService] Firebaseが初期化されていません。Firebase機能は使用できません。");
        debugPrint("⚠️ [FirebaseService] Firebase.initializeApp()がmain.dartで呼び出されているか確認してください。");
        _initializationFailed = true;
        return;
      }
      
      // Firebase.app()を安全に取得
      FirebaseApp app;
      try {
        // まずFirebase.appsが空でないことを確認
        if (Firebase.apps.isEmpty) {
          throw FirebaseServiceError('Firebaseアプリが初期化されていません');
        }
        
        // デフォルトアプリを取得（[DEFAULT]アプリ）
        try {
          app = Firebase.app();
        } catch (e) {
          // デフォルトアプリが取得できない場合は、最初のアプリを使用
          if (Firebase.apps.isNotEmpty) {
            app = Firebase.apps.first;
            debugPrint("⚠️ [FirebaseService] デフォルトアプリの取得に失敗したため、最初のアプリを使用: ${app.name}");
          } else {
            throw FirebaseServiceError('Firebaseアプリが見つかりません');
          }
        }
      } catch (e) {
        debugPrint("❌ [FirebaseService] Firebase.app()の取得に失敗: $e");
        rethrow;
      }
      
      // StorageとDatabaseを初期化
      _storage = FirebaseStorage.instanceFor(bucket: _storageBucketURL);
      _database = FirebaseDatabase.instanceFor(app: app, databaseURL: _databaseURL);
      
      debugPrint("✅ [FirebaseService] Storage Bucket: $_storageBucketURL");
      debugPrint("✅ [FirebaseService] Realtime Database URL: $_databaseURL");
      debugPrint("✅ [FirebaseService] 初期化完了");
      
      // 初期化失敗フラグをリセット
      _initializationFailed = false;
      
      // 匿名認証は非同期で行う（初期化失敗の原因にならないように）
      _ensureAuthenticated().catchError((e) {
        debugPrint("⚠️ [FirebaseService] 匿名認証は後で再試行されます: $e");
      });
    } catch (e, stackTrace) {
      debugPrint("❌ [FirebaseService] 初期化エラー: $e");
      debugPrint("❌ [FirebaseService] スタックトレース: $stackTrace");
      _initializationFailed = true;
      _storage = null;
      _database = null;
      rethrow; // エラーを再スローして、呼び出し元に通知
    } finally {
      _isInitializing = false;
    }
  }

  /// 匿名認証を確実に行う（Storageアクセス用）
  Future<void> _ensureAuthenticated() async {
    try {
      // 現在の認証状態を確認
      User? currentUser = _auth.currentUser;
      debugPrint("🔐 [FirebaseService] 認証状態確認: ${currentUser != null ? '認証済み (${currentUser.uid})' : '未認証'}");
      
      if (currentUser == null) {
        debugPrint("🔐 [FirebaseService] 匿名認証を開始...");
        final userCredential = await _auth.signInAnonymously();
        debugPrint("✅ [FirebaseService] 匿名認証成功: ${userCredential.user?.uid}");
        debugPrint("✅ [FirebaseService] 認証タイプ: ${userCredential.user?.isAnonymous == true ? '匿名' : 'その他'}");
      } else {
        debugPrint("✅ [FirebaseService] 既に認証済み: ${currentUser.uid}");
        debugPrint("✅ [FirebaseService] 認証タイプ: ${currentUser.isAnonymous ? '匿名' : 'その他'}");
      }
      
      // 認証後の状態を再確認
      final finalUser = _auth.currentUser;
      if (finalUser == null) {
        throw FirebaseServiceError('認証が完了しませんでした');
      }
      debugPrint("✅ [FirebaseService] 最終認証状態: ${finalUser.uid} (匿名: ${finalUser.isAnonymous})");
    } catch (e) {
      debugPrint("❌ [FirebaseService] 匿名認証エラー: $e");
      debugPrint("❌ [FirebaseService] エラータイプ: ${e.runtimeType}");
      
      // 認証エラーの場合は例外を再スロー
      if (e is FirebaseAuthException) {
        throw FirebaseServiceError(
          'Firebase認証に失敗しました: ${e.message}。Firebase Consoleで匿名認証が有効になっているか確認してください。',
          code: e.code,
        );
      }
      throw FirebaseServiceError('認証に失敗しました: $e');
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
  
  /// Firebaseの初期化を確実に行う（必要に応じて再試行）
  Future<void> ensureInitialized() async {
    if (isConfigured) {
      return; // 既に初期化済み
    }
    
    // 既に初期化中の場合は、そのFutureを待つ
    if (_initializationFuture != null) {
      try {
        await _initializationFuture;
        return;
      } catch (e) {
        // 初期化に失敗した場合は、再試行を許可
        debugPrint("🔄 [FirebaseService] 初期化失敗後の再試行を開始: $e");
        _initializationFuture = null;
        _initializationFailed = false;
      }
    }
    
    if (_initializationFailed) {
      // 初期化に失敗した場合は、再試行を許可
      debugPrint("🔄 [FirebaseService] 初期化失敗後の再試行を開始");
      _initializationFailed = false;
    }
    
    // 初期化を実行（Futureを保持して、複数の呼び出しが同時に行われても1回だけ実行されるようにする）
    _initializationFuture = _initAsync();
    
    try {
      await _initializationFuture;
    } catch (e) {
      debugPrint("❌ [FirebaseService] ensureInitialized() でエラー: $e");
      _initializationFuture = null;
      throw FirebaseServiceError('Firebaseの初期化に失敗しました: $e');
    }
    
    if (!isConfigured) {
      _initializationFuture = null;
      throw FirebaseServiceError('Firebaseの初期化に失敗しました');
    }
  }

  /// 画像をFirebase Storageにアップロード
  Future<String> uploadImage(File imageFile, String teamId, String eventId, int problemIndex) async {
    await ensureInitialized();
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      // 画像を圧縮（最大1920px、JPEG品質70）
      final imageData = await _compressImage(imageFile, maxDimension: 1920, quality: 70);
      
      final fileName = "check_images/$teamId/$eventId/problem_${problemIndex}_${_uuid.v4()}.jpg";
      if (_storage == null) throw FirebaseServiceError('Firebase Storageが初期化されていません');
      final Reference ref = _storage!.ref().child(fileName);
      
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
    await ensureInitialized();
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      // 画像を圧縮（既存の _compressImage を利用）
      final imageData = await _compressImage(imageFile, maxDimension: 1920, quality: 70);
      
      // パスを「reference_images/{eventId}/{problemId}/...」で整理
      final fileName = "reference_images/$eventId/$problemId/ref_image_${_uuid.v4()}.jpg";
      if (_storage == null) throw FirebaseServiceError('Firebase Storageが初期化されていません');
      final Reference ref = _storage!.ref().child(fileName);
      
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
    await ensureInitialized();
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      // 認証を確実に行う
      await _ensureAuthenticated();
      
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
      if (_storage == null) throw FirebaseServiceError('Firebase Storageが初期化されていません');
      final Reference ref = _storage!.ref().child(fileName);

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

  // MARK: - Storage: イベントカード画像アップロード
  
  /// イベントカード画像をFirebase Storageにアップロード
  Future<String> uploadEventCardImage(File imageFile, {required String eventId}) async {
    await ensureInitialized();
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      // 認証を確実に行う（エラーが発生した場合は例外をスロー）
      await _ensureAuthenticated();
      
      // 認証状態を再確認
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw FirebaseServiceError('認証が完了していません。Firebase Consoleで匿名認証が有効になっているか確認してください。');
      }
      debugPrint("📤 [FirebaseService] イベントカード画像アップロード開始 (認証済み: ${currentUser.uid})");
      
      // 画像を圧縮（最大1920px、JPEG品質70）
      final imageData = await _compressImage(imageFile, maxDimension: 1920, quality: 70);
      
      // パスを「{eventId}/card_image/...」で整理
      final fileName = "$eventId/card_image/card_${_uuid.v4()}.jpg";
      if (_storage == null) throw FirebaseServiceError('Firebase Storageが初期化されていません');
      final Reference ref = _storage!.ref().child(fileName);
      
      debugPrint("📤 [FirebaseService] アップロード先: $fileName");
      
      // アップロード
      final UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: "image/jpeg"));
      final TaskSnapshot snapshot = await uploadTask;
      
      // ダウンロードURLを取得
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint("✅ [FirebaseService] イベントカード画像アップロード成功: $downloadUrl");
      return downloadUrl;
    } on FirebaseServiceError {
      rethrow; // FirebaseServiceErrorはそのまま再スロー
    } catch (e) {
      debugPrint("❌ [FirebaseService] イベントカード画像アップロード失敗: $e");
      debugPrint("❌ [FirebaseService] エラータイプ: ${e.runtimeType}");
      
      // 認証エラーの場合は詳細なメッセージを返す
      if (e.toString().contains('unauthorized') || e.toString().contains('permission')) {
        throw FirebaseServiceError(
          'Firebase Storageへのアクセスが拒否されました。\n'
          '以下の設定を確認してください：\n'
          '1. Firebase Console → Authentication → Sign-in method → 匿名認証を有効化\n'
          '2. Firebase Console → Storage → Rules で認証済みユーザーの書き込みを許可\n'
          '例: allow write: if request.auth != null;',
          code: 'unauthorized',
        );
      }
      
      throw FirebaseServiceError('イベントカード画像アップロードに失敗しました: $e', code: 'upload-failed');
    }
  }

  // MARK: - Storage: メディア画像アップロード
  
  /// 問題のメディア画像をFirebase Storageにアップロード
  Future<String> uploadMediaImage(File imageFile, String eventId, String problemId) async {
    await ensureInitialized();
    if (!isConfigured) {
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }

    try {
      // 認証を確実に行う（エラーが発生した場合は例外をスロー）
      await _ensureAuthenticated();
      
      // 認証状態を再確認
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw FirebaseServiceError('認証が完了していません。Firebase Consoleで匿名認証が有効になっているか確認してください。');
      }
      debugPrint("📤 [FirebaseService] メディア画像アップロード開始 (認証済み: ${currentUser.uid})");
      
      // 画像を圧縮（最大1920px、JPEG品質70）
      final imageData = await _compressImage(imageFile, maxDimension: 1920, quality: 70);
      
      // パスを「{eventId}/media/{problemId}/...」で整理
      final fileName = "$eventId/media/${problemId}_image_${_uuid.v4()}.jpg";
      if (_storage == null) throw FirebaseServiceError('Firebase Storageが初期化されていません');
      final Reference ref = _storage!.ref().child(fileName);
      
      debugPrint("📤 [FirebaseService] アップロード先: $fileName");
      
      // アップロード
      final UploadTask uploadTask = ref.putData(imageData, SettableMetadata(contentType: "image/jpeg"));
      final TaskSnapshot snapshot = await uploadTask;
      
      // ダウンロードURLを取得
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint("✅ [FirebaseService] メディア画像アップロード成功: $downloadUrl");
      return downloadUrl;
    } on FirebaseServiceError {
      rethrow; // FirebaseServiceErrorはそのまま再スロー
    } catch (e) {
      debugPrint("❌ [FirebaseService] メディア画像アップロード失敗: $e");
      debugPrint("❌ [FirebaseService] エラータイプ: ${e.runtimeType}");
      
      // 認証エラーの場合は詳細なメッセージを返す
      if (e.toString().contains('unauthorized') || e.toString().contains('permission')) {
        throw FirebaseServiceError(
          'Firebase Storageへのアクセスが拒否されました。\n'
          '以下の設定を確認してください：\n'
          '1. Firebase Console → Authentication → Sign-in method → 匿名認証を有効化\n'
          '2. Firebase Console → Storage → Rules で認証済みユーザーの書き込みを許可\n'
          '例: allow write: if request.auth != null;',
          code: 'unauthorized',
        );
      }
      
      throw FirebaseServiceError('メディア画像アップロードに失敗しました: $e', code: 'upload-failed');
    }
  }

  // MARK: - Realtime Database: 進捗管理
  
  /// チームの進捗を取得
  Future<TeamProgress?> getTeamProgress(String teamId, String eventId) async {
    await ensureInitialized();
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
    
    // 認証状態を確認し、必要に応じて匿名認証を実行
    await _ensureAuthenticated();

    if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
    final ref = _database!.ref().child("team_progress/$teamId/$eventId");
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
    
    if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
    final ref = _database!.ref().child("team_progress/$teamId/$eventId");
    
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
  await ensureInitialized();
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
  
  // 認証状態を確認し、必要に応じて匿名認証を実行
  await _ensureAuthenticated();

  // チーム名は小文字にしてチェックすることが一般的です
  final normalizedTeamName = teamName.toLowerCase().trim();
  
  // Realtime Databaseのパスを設定
  if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
  final ref = _database!.ref().child("teams/$eventId");

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
    await ensureInitialized();
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
    
    // 認証状態を確認し、必要に応じて匿名認証を実行
    await _ensureAuthenticated();

    // Realtime Databaseのパス: team_progress/{teamId}/{eventId}
    if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
    final ref = _database!.ref().child("team_progress/${progress.teamId}/${progress.eventId}");
    
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
    await ensureInitialized();
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
    
    // 認証状態を確認し、必要に応じて匿名認証を実行
    await _ensureAuthenticated();

    // Realtime Databaseのパスを作成
    if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
    final ref = _database!.ref().child("escape_records/$eventId/${record.id}");
    
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
    await ensureInitialized();
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
    
    if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
    final ref = _database!.ref().child("passcodes/ADMIN_CREATE_PASSCODES/$passcode/events_created");
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
    debugPrint("🔄 [FirebaseService] getAllEvents() 開始");
    
    // Firebaseの初期化を確実に行う
    await ensureInitialized();
    
    if (!isConfigured) {
      debugPrint("❌ [FirebaseService] Firebaseが初期化されていません");
      throw FirebaseServiceError('Firebaseが初期化されていません');
    }
    
    // 認証状態を確認し、必要に応じて匿名認証を実行
    await _ensureAuthenticated();
    
    debugPrint("✅ [FirebaseService] Firebase初期化確認完了");
    debugPrint("📡 [FirebaseService] Database URL: $_databaseURL");
    
    if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
    final ref = _database!.ref().child("events");
    debugPrint("📡 [FirebaseService] Firebase Realtime Databaseからイベントを取得: events/");
    
    try {
      debugPrint("⏳ [FirebaseService] データ取得中...");
      // タイムアウトを設定（30秒）
      final snapshot = await ref.get().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint("❌ [FirebaseService] データ取得がタイムアウトしました（30秒）");
          throw FirebaseServiceError('データ取得がタイムアウトしました。ネットワーク接続を確認してください。');
        },
      );
      debugPrint("📦 [FirebaseService] スナップショット取得完了");
      
      if (!snapshot.exists) {
        debugPrint("⚠️ [FirebaseService] スナップショットが存在しません (snapshot.exists = false)");
        return [];
      }
      
      if (snapshot.value == null) {
        debugPrint("⚠️ [FirebaseService] スナップショットの値がnullです");
        return [];
      }
      
      debugPrint("📊 [FirebaseService] スナップショットの型: ${snapshot.value.runtimeType}");
      debugPrint("📊 [FirebaseService] スナップショットの値: ${snapshot.value}");
      
      // Dartでは Map<dynamic, dynamic> として取得されるため、型変換が必要
      if (snapshot.value is! Map) {
        debugPrint("❌ [FirebaseService] スナップショットの値がMap型ではありません: ${snapshot.value.runtimeType}");
        return [];
      }
      
      final Map<String, dynamic> eventsDict = Map<String, dynamic>.from(snapshot.value as Map);
      debugPrint("📋 [FirebaseService] イベント辞書のキー数: ${eventsDict.length}");
      debugPrint("📋 [FirebaseService] イベント辞書のキー: ${eventsDict.keys.toList()}");
      
      List<Event> events = [];
      for (var entry in eventsDict.entries) {
        final eventId = entry.key;
        final eventData = entry.value;
        try {
          debugPrint("🔄 [FirebaseService] イベント処理中: ID=$eventId");
          
          if (eventData is! Map) {
            debugPrint("⚠️ [FirebaseService] イベントデータがMap型ではありません (ID: $eventId): ${eventData.runtimeType}");
            continue;
          }
          
          // Event.fromJson を使ってパースを試みる
          final eventDataMap = Map<String, dynamic>.from(eventData as Map);
          debugPrint("📝 [FirebaseService] イベントデータマップ: $eventDataMap");
          
          // キーとして保存されているeventIdをidフィールドとして設定
          // （Firebase Realtime Databaseではキーとデータが分離されているため）
          if (!eventDataMap.containsKey('id') || eventDataMap['id'] == null || (eventDataMap['id'] as String).isEmpty) {
            eventDataMap['id'] = eventId;
            debugPrint("📝 [FirebaseService] イベントIDをキーから設定: $eventId");
          }
          
          debugPrint("🔄 [FirebaseService] Event.fromJson() を呼び出し中...");
          final event = Event.fromJson(eventDataMap);
          debugPrint("✅ [FirebaseService] イベントパース成功: ${event.name} (ID: ${event.id}, isVisible: ${event.isVisible}, eventDate: ${event.eventDate})");
          
          // escape_recordsからレコードを取得して追加
          try {
            final recordsRef = _database!.ref().child("escape_records/$eventId");
            final recordsSnapshot = await recordsRef.get().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                debugPrint("⚠️ [FirebaseService] escape_records取得がタイムアウトしました (ID: $eventId)");
                throw TimeoutException('escape_records取得タイムアウト');
              },
            );
            if (recordsSnapshot.exists && recordsSnapshot.value != null) {
              final recordsData = recordsSnapshot.value;
              List<EscapeRecord> escapeRecords = [];
              
              if (recordsData is Map) {
                final recordsMap = Map<String, dynamic>.from(recordsData);
                recordsMap.forEach((recordId, recordValue) {
                  try {
                    if (recordValue is Map) {
                      final recordMap = Map<String, dynamic>.from(recordValue);
                      recordMap['id'] = recordId; // キーをIDとして使用
                      escapeRecords.add(EscapeRecord.fromJson(recordMap));
                    }
                  } catch (e) {
                    debugPrint("⚠️ [FirebaseService] EscapeRecordパースエラー (ID: $recordId): $e");
                  }
                });
              }
              
              if (escapeRecords.isNotEmpty) {
                // 既存のrecordsとマージ（重複を避ける）
                final existingRecordIds = event.records.map((r) => r.id).toSet();
                final newRecords = escapeRecords.where((r) => !existingRecordIds.contains(r.id)).toList();
                if (newRecords.isNotEmpty) {
                  final updatedEvent = event.copyWith(records: [...event.records, ...newRecords]);
                  events.add(updatedEvent);
                  debugPrint("✅ [FirebaseService] ${newRecords.length}件のレコードを追加: ${event.id}");
                } else {
                  events.add(event);
                }
              } else {
                events.add(event);
              }
            } else {
              events.add(event);
            }
          } catch (e) {
            debugPrint("⚠️ [FirebaseService] escape_records取得エラー (ID: $eventId): $e");
            // エラーが発生してもイベントは追加
            events.add(event);
          }
        } catch (e, stackTrace) {
          debugPrint("❌ [FirebaseService] イベントパース失敗 (ID: $eventId): $e");
          debugPrint("❌ [FirebaseService] スタックトレース: $stackTrace");
          // パースエラーが発生しても他のイベントの処理を続行
        }
      }

      debugPrint("✅ [FirebaseService] パース完了: ${events.length}件のイベントを取得");
      if (events.isEmpty && eventsDict.isNotEmpty) {
        debugPrint("⚠️ [FirebaseService] 警告: イベント辞書には${eventsDict.length}件のデータがあるが、パースできたイベントは0件です");
      }
      return events;
    } on PlatformException catch (e, stackTrace) {
      debugPrint("❌ [FirebaseService] Firebase読み込みエラー (PlatformException): $e");
      debugPrint("❌ [FirebaseService] エラーコード: ${e.code}");
      debugPrint("❌ [FirebaseService] エラーメッセージ: ${e.message}");
      debugPrint("❌ [FirebaseService] スタックトレース: $stackTrace");
      
      // 権限エラーの場合の詳細メッセージ
      if (e.code == 'PERMISSION_DENIED' || e.code == 'permission-denied' || e.message?.contains('Permission denied') == true) {
        throw FirebaseServiceError(
          'Firebase Databaseへのアクセスが拒否されました。\n'
          'Firebase Consoleで以下の設定を確認してください：\n'
          '1. Realtime Database → Rules で読み取り権限が設定されているか\n'
          '2. APIキーが正しく設定されているか\n'
          '3. プロジェクトの認証設定が正しいか',
          code: e.code,
        );
      }
      
      throw FirebaseServiceError('Firebase Databaseからのデータ取得に失敗しました: ${e.message}', code: e.code);
    } on FirebaseException catch (e, stackTrace) {
      debugPrint("❌ [FirebaseService] Firebase読み込みエラー (FirebaseException): $e");
      debugPrint("❌ [FirebaseService] エラーコード: ${e.code}");
      debugPrint("❌ [FirebaseService] エラーメッセージ: ${e.message}");
      debugPrint("❌ [FirebaseService] スタックトレース: $stackTrace");
      
      // 権限エラーの場合の詳細メッセージ
      if (e.code == 'PERMISSION_DENIED' || e.code == 'permission-denied') {
        throw FirebaseServiceError(
          'Firebase Databaseへのアクセスが拒否されました。\n'
          'Firebase Consoleで以下の設定を確認してください：\n'
          '1. Realtime Database → Rules で読み取り権限が設定されているか\n'
          '2. APIキーが正しく設定されているか\n'
          '3. プロジェクトの認証設定が正しいか',
          code: e.code,
        );
      }
      
      throw FirebaseServiceError('Firebase Databaseからのデータ取得に失敗しました: ${e.message}', code: e.code);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint("❌ [FirebaseService] タイムアウトエラー: $e");
      debugPrint("❌ [FirebaseService] スタックトレース: $stackTrace");
      throw FirebaseServiceError('データ取得がタイムアウトしました。ネットワーク接続を確認してください。');
    } catch (e, stackTrace) {
      debugPrint("❌ [FirebaseService] Firebase読み込みエラー: $e");
      debugPrint("❌ [FirebaseService] エラーの型: ${e.runtimeType}");
      debugPrint("❌ [FirebaseService] スタックトレース: $stackTrace");
      throw FirebaseServiceError.fromFirebaseDatabaseError(e);
    }
  }
  // MARK: - Realtime Database: イベント/問題データ 👈 このセクションとして追記

/// イベントを保存または更新する（問題データを含む）
Future<void> saveEvent(Event event) async {
  // ⚠️ 注意: EventモデルにはList<Problem>が含まれている必要があります
  await ensureInitialized();
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
  
  // 認証状態を確認し、必要に応じて匿名認証を実行
  await _ensureAuthenticated();
  
  if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
  final ref = _database!.ref().child("events/${event.id}");
  
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
  await ensureInitialized();
  if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');
  
  // 認証状態を確認し、必要に応じて匿名認証を実行
  await _ensureAuthenticated();
  
  if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
  final ref = _database!.ref().child("events/$eventId");
  
  try {
    await ref.remove();
    debugPrint("✅ [FirebaseService] イベントデータ削除成功: $eventId");
  } catch (e) {
    debugPrint("❌ [FirebaseService] イベントデータの削除に失敗: $e");
    throw FirebaseServiceError.fromFirebaseDatabaseError(e);
  }
}
  // MARK: - Realtime Database: ユーザー/デバイス情報 (追記)
  
  /// ユーザーの端末情報をFirebase Realtime Databaseに保存/更新
  /// パス: device_info/{deviceId}
  Future<void> saveUserDeviceInfo(UserDeviceInfo info) async {
    await ensureInitialized();
    if (!isConfigured) throw FirebaseServiceError('Firebaseが初期化されていません');

    // Realtime Databaseのパスを作成。deviceIdを一意のキーとする
    if (_database == null) throw FirebaseServiceError('Firebase Databaseが初期化されていません');
    final ref = _database!.ref().child("device_info/${info.deviceId}");
    
    try {
      // UserDeviceInfoオブジェクトをMapに変換してデータベースに書き込む
      await ref.set(info.toJson());
      debugPrint("✅ [FirebaseService] デバイス情報保存成功: ${info.deviceId}");
    } catch (e) {
      debugPrint("❌ [FirebaseService] デバイス情報の保存に失敗: $e");
      throw FirebaseServiceError.fromFirebaseDatabaseError(e);
    }
  }
}