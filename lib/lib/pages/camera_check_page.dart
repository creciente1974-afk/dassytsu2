import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// サービスとモデルのインポート
import '../models/problem.dart';
import '../lib/models/team_progress.dart' show TeamProgress, CheckStatus; // TeamProgressとCheckStatusをインポート
import '../../firebase_service.dart';
import '../../lib/services/firebase_service_error.dart';

// 仮の画像比較ロジック（Method Channelの代替スタブ）
// 実際にはネイティブコードのVisionで実装されます。
// 

class CameraCheckPage extends StatefulWidget {
  final Problem problem;
  final String eventId;
  final int problemIndex;
  final String teamId;
  final bool isLastProblem; // 最後の問題かどうか
  
  // 認証成功・失敗時のコールバック（画面遷移などに使用）
  final VoidCallback onApproved;
  final VoidCallback onRejected;
  
  // 最後の問題の場合、クリアページへ遷移するコールバック
  final VoidCallback? onNavigateToClearPage;
  
  // 自動認証の閾値（Swiftコードのロジックに合わせる）
  static const double similarityThreshold = 0.7;

  const CameraCheckPage({
    required this.problem,
    required this.eventId,
    required this.problemIndex,
    required this.teamId,
    required this.isLastProblem,
    required this.onApproved,
    required this.onRejected,
    this.onNavigateToClearPage,
    super.key,
  });

  @override
  State<CameraCheckPage> createState() => _CameraCheckPageState();
}

class _CameraCheckPageState extends State<CameraCheckPage> with WidgetsBindingObserver {
  // MARK: - サービスとコントローラー
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  
  // MARK: - Method Channel for Foreground Service (Android only)
  static const MethodChannel _foregroundServiceChannel = MethodChannel('com.dassyutsu2.dassyutsu_app/camera_foreground_service');
  
  // MARK: - UIの状態変数
  File? _selectedImage;                  // 撮影したローカル画像ファイル
  CheckStatus _checkStatus = CheckStatus.notStarted; // 現在の認証ステータス
  bool _isUploading = false;             // アップロード中フラグ
  bool _isCheckingAutomatically = false; // 自動認証処理中フラグ
  bool _hasAttemptedAutoCheck = false;   // 自動認証を試みたか
  String? _uploadError;                  // エラーメッセージ
  bool _hasCalledApproved = false;       // onApproved()が既に呼ばれたか（重複防止）
  bool _hasCalledRejected = false;       // onRejected()が既に呼ばれたか（重複防止）
  bool _isInitialLoad = true;            // 初回データ読み込みフラグ（既存のapproved状態を無視するため）
  bool _isCameraPicking = false;         // カメラ撮影中フラグ
  bool _wasCameraCancelled = false;      // カメラ撮影がキャンセルされたか（アプリがバックグラウンドに移行した場合）
  Timer? _wakelockKeepAliveTimer;       // WakeLockを保持するためのタイマー

  // MARK: - Firebaseの監視
  StreamSubscription<TeamProgress?>? _progressSubscription;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // デバッグ: problemの情報を確認
    debugPrint('📸 [CameraCheckPage] initState');
    debugPrint('   - problem.id: ${widget.problem.id}');
    debugPrint('   - problem.checkText: ${widget.problem.checkText}');
    debugPrint('   - problem.checkImageURL: ${widget.problem.checkImageURL}');
    debugPrint('   - problem.requiresCheck: ${widget.problem.requiresCheck}');
    
    try {
      _loadInitialProgressAndStartObserving();
      // Swiftコードでは見本画像をダウンロードしていましたが、ここでは
      // 自動認証のスタブを使用するため、ダウンロードロジックはスキップします。
    } catch (e, stackTrace) {
      debugPrint('❌ [CameraCheckPage] initStateでエラー: $e');
      debugPrint('スタックトレース: $stackTrace');
      // エラーが発生してもページは表示される
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('📸 [CameraCheckPage] didChangeAppLifecycleState: $state');
    debugPrint('   - _isCameraPicking: $_isCameraPicking');
    debugPrint('   - mounted: $mounted');
    debugPrint('   - _selectedImage: ${_selectedImage?.path ?? "null"}');
    
    // バックグラウンドに移行した際の処理
    // 注意: pickImage()を呼び出すと、ネイティブカメラアプリが起動し、
    // Flutterアプリが一時的にバックグラウンドに移行します（inactive → hidden → paused）。
    // これは正常な動作なので、pickImage()を呼び出した後のバックグラウンド移行は無視します。
    // カメラ撮影開始前（pickImage()を呼び出す前）にバックグラウンドに移行した場合のみキャンセルします。
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      debugPrint('📸 [CameraCheckPage] アプリがバックグラウンドに移行しました');
      debugPrint('   - _isCameraPicking: $_isCameraPicking');
      debugPrint('   - _wasCameraCancelled: $_wasCameraCancelled');
      
      // pickImage()を呼び出した後（カメラ撮影中）にバックグラウンドに移行した場合、
      // WakeLockを即座に再有効化してアプリがキルされるのを防ぐ
      if (_isCameraPicking && !_wasCameraCancelled) {
        debugPrint('🔒 [CameraCheckPage] カメラ撮影中にバックグラウンド移行を検知。WakeLockを再有効化します。');
        // 即座にWakeLockを再有効化（複数回試行して確実に保持する）
        _renewWakeLockImmediately();
      }
      
      // pickImage()を呼び出す前にバックグラウンドに移行した場合のみキャンセル
      // pickImage()を呼び出した後は、カメラアプリが起動してバックグラウンドに移行するのは正常な動作
      // そのため、_isCameraPickingがtrueの場合は、pickImage()を呼び出した後と判断し、キャンセルしない
      // （ただし、既にキャンセルされている場合は何もしない）
      if (!_isCameraPicking && !_wasCameraCancelled) {
        debugPrint('⚠️ [CameraCheckPage] カメラ撮影開始前にアプリがバックグラウンドに移行しました');
        debugPrint('⚠️ [CameraCheckPage] カメラ撮影をスキップしてフォトライブラリから選択します');
        // カメラ撮影をスキップしてフォトライブラリから選択
        _wasCameraCancelled = true;
        _pickImageFromGallery();
      }
    }
    
    if (state == AppLifecycleState.resumed) {
      debugPrint('📸 [CameraCheckPage] アプリがフォアグラウンドに戻りました');
      if (_wasCameraCancelled) {
        debugPrint('📸 [CameraCheckPage] カメラ撮影がキャンセルされました。フォトライブラリから画像を選択します。');
        // カメラ撮影がキャンセルされた場合、フォトライブラリから画像を選択
        _wasCameraCancelled = false;
        _pickImageFromGallery();
      } else if (_isCameraPicking) {
        debugPrint('📸 [CameraCheckPage] カメラ撮影中のフラグがtrueのままです');
        debugPrint('📸 [CameraCheckPage] pickImage()のFutureが完了するまで待機中...');
        // カメラ撮影中にアプリがフォアグラウンドに戻った場合、
        // pickImage()のFutureが完了するまで待機する
        // 複数回チェックして、Futureが完了するまで待つ
        _checkCameraPickCompletion();
      } else {
        debugPrint('📸 [CameraCheckPage] カメラ撮影中ではない状態です');
      }
    }
  }
  
  // カメラ撮影の完了を確認する（複数回チェック）
  void _checkCameraPickCompletion() {
    // 最初のチェック（1秒後）- pickImage()のFutureが完了するまで少し待つ
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      if (!_isCameraPicking) {
        debugPrint('✅ [CameraCheckPage] カメラ撮影が完了しました（1秒後）');
        return;
      }
      debugPrint('📸 [CameraCheckPage] カメラ撮影がまだ進行中です（1秒後）');
      debugPrint('   - _isCameraPicking: $_isCameraPicking');
      debugPrint('   - _selectedImage: ${_selectedImage?.path ?? "null"}');
      
      // 2回目のチェック（3秒後）
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (!mounted) return;
        if (!_isCameraPicking) {
          debugPrint('✅ [CameraCheckPage] カメラ撮影が完了しました（3秒後）');
          return;
        }
        debugPrint('📸 [CameraCheckPage] カメラ撮影がまだ進行中です（3秒後）');
        debugPrint('   - _isCameraPicking: $_isCameraPicking');
        debugPrint('   - _selectedImage: ${_selectedImage?.path ?? "null"}');
        
        // 3回目のチェック（10秒後）- 長時間待っても完了しない場合はタイムアウトとみなす
        Future.delayed(const Duration(milliseconds: 7000), () {
          if (!mounted) return;
          debugPrint('📸 [CameraCheckPage] フォアグラウンド復帰後の状態確認（10秒後）');
          debugPrint('   - _isCameraPicking: $_isCameraPicking');
          debugPrint('   - _selectedImage: ${_selectedImage?.path ?? "null"}');
          debugPrint('   - mounted: $mounted');
          
          // もし_isCameraPickingがまだtrueで、_selectedImageがnullの場合、
          // pickImage()のFutureが完了していない可能性がある
          // この場合、カメラ撮影がキャンセルされたか、タイムアウトした可能性がある
          if (_isCameraPicking && _selectedImage == null) {
            debugPrint('⚠️ [CameraCheckPage] _isCameraPickingがまだtrueで、画像が選択されていません');
            debugPrint('⚠️ [CameraCheckPage] カメラ撮影がタイムアウトまたはキャンセルされた可能性があります。状態をリセットします。');
            // WakeLockを無効化
            _disableWakeLock();
            // 状態をリセット
            if (mounted) {
              setState(() {
                _isCameraPicking = false;
                _uploadError = 'カメラ撮影が中断されました。もう一度お試しください。';
              });
            }
          }
        });
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    debugPrint('📸 [CameraCheckPage] dispose() called');
    debugPrint('   - _selectedImage: ${_selectedImage?.path ?? "null"}');
    debugPrint('   - _checkStatus: $_checkStatus');
    debugPrint('   - _isCameraPicking: $_isCameraPicking');
    
    // メモリ使用量を削減するため、画像ファイルの参照を明示的にクリア
    _selectedImage = null;
    
    // WakeLockの保持タイマーを停止
    _wakelockKeepAliveTimer?.cancel();
    _wakelockKeepAliveTimer = null;
    
    // WakeLockを無効化（dispose時にも念のため）
    _disableWakeLock();
    
    // Androidのみ: Foreground Serviceを停止（dispose時にも念のため）
    // 注意: disposeは同期関数なので、awaitは使用できない
    if (Platform.isAndroid) {
      _foregroundServiceChannel.invokeMethod('stopForegroundService').catchError((e) {
        debugPrint('⚠️ [CameraCheckPage] Foreground Serviceの停止に失敗しました（dispose時）: $e');
      });
      debugPrint('✅ [CameraCheckPage] Foreground Serviceを停止しました（dispose時）');
    }
    
    // 画面が閉じられるときにFirebaseの監視を停止する
    _progressSubscription?.cancel();
    super.dispose();
  }

  // MARK: - 1. Firebase 進捗の監視と初期化

  // Swiftの loadInitialProgress に相当するロジック
  void _loadInitialProgressAndStartObserving() {
    _progressSubscription?.cancel();

    debugPrint('📡 [CameraCheckPage] Starting Firebase observation...');
    debugPrint('   - teamId: ${widget.teamId}');
    debugPrint('   - eventId: ${widget.eventId}');
    
      // 監視を開始
    try {
      _progressSubscription = _firebaseService
          .observeTeamProgress(widget.teamId, widget.eventId)
          .listen(
        (progress) async {
          try {
            debugPrint('📡 [CameraCheckPage] Firebase progress update received');
            debugPrint('   - progress: ${progress?.currentProblemIndex ?? "null"}');
            // 1. データがない場合、初期データを作成し、Realtime Databaseに書き込む
            if (progress == null || progress.currentProblemIndex != widget.problemIndex) {
              final initialProgress = TeamProgress(
                teamId: widget.teamId,
                eventId: widget.eventId,
                currentProblemIndex: widget.problemIndex,
                checkStatus: CheckStatus.notStarted,
              );
              // DBに初期状態を書き込み（非同期なので待たない）
              try {
                await _firebaseService.updateTeamProgress(initialProgress);
              } catch (e, stackTrace) {
                debugPrint('❌ [CameraCheckPage] 進捗更新エラー: $e');
                debugPrint('スタックトレース: $stackTrace');
                if (mounted) {
                  setState(() {
                    _uploadError = '進捗データの更新に失敗しました。';
                  });
                }
              }
              return;
            }

            // 2. データが現在の問題と一致する場合、UIの状態を更新
            if (_checkStatus != progress.checkStatus && mounted) {
              setState(() {
                _checkStatus = progress.checkStatus;
              });

              // 初回読み込み時に既にapprovedの状態だった場合は、それを無視する
              // （ユーザーが実際に画像をアップロードして認証された場合のみonApproved()を呼ぶ）
              if (_isInitialLoad) {
                _isInitialLoad = false;
                if (progress.checkStatus == CheckStatus.approved) {
                  debugPrint('⚠️ [CameraCheckPage] 初回読み込み時に既にapprovedの状態を検知しました。これを無視し、notStartedにリセットします。');
                  // 既存のapproved状態を無視し、notStartedにリセット
                  final resetProgress = TeamProgress(
                    teamId: widget.teamId,
                    eventId: widget.eventId,
                    currentProblemIndex: widget.problemIndex,
                    checkStatus: CheckStatus.notStarted,
                  );
                  try {
                    await _firebaseService.updateTeamProgress(resetProgress);
                    if (mounted) {
                      setState(() {
                        _checkStatus = CheckStatus.notStarted;
                      });
                    }
                  } catch (e, stackTrace) {
                    debugPrint('❌ [CameraCheckPage] 状態リセットエラー: $e');
                    debugPrint('スタックトレース: $stackTrace');
                  }
                  return; // 初回読み込み時のapproved状態は無視して終了
                }
              }

              // 状態に応じた後続処理（重複呼び出しを防ぐ）
              // 注意: 認証成功時はonApproved()を呼ばず、ユーザーが手動で「次へ進む」ボタンを押すまで待つ
              // これにより、ユーザーが撮影した画像を確認できる
              if (progress.checkStatus == CheckStatus.rejected && !_hasCalledRejected) {
                _hasCalledRejected = true;
                debugPrint('❌ [CameraCheckPage] Firebaseリスナーから認証失敗を検知 - onRejected()を呼び出します');
                // 少し遅延を入れて、状態更新が完了してからコールバックを呼ぶ
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    try {
                      widget.onRejected(); // 拒否されたら（必要に応じて画面遷移またはリセット）
                      _resetStateForRetry();
                    } catch (e, stackTrace) {
                      debugPrint('❌ [CameraCheckPage] onRejected()呼び出しエラー: $e');
                      debugPrint('スタックトレース: $stackTrace');
                    }
                  }
                });
              }
            }
          } catch (e, stackTrace) {
              debugPrint('❌ [CameraCheckPage] Firebaseリスナーのコールバック内でエラー: $e');
              debugPrint('スタックトレース: $stackTrace');
              if (mounted) {
                setState(() {
                  _uploadError = 'データの処理中にエラーが発生しました。';
                });
              }
            }
          },
        onError: (error, stackTrace) {
            debugPrint('❌ [CameraCheckPage] Firebaseストリームエラー: $error');
            debugPrint('スタックトレース: $stackTrace');
            if (mounted) {
              setState(() {
                _uploadError = 'データベースへの接続中にエラーが発生しました。';
              });
            }
          },
        );
      } catch (e, stackTrace) {
        debugPrint('❌ [CameraCheckPage] ストリーム監視の開始エラー: $e');
        debugPrint('スタックトレース: $stackTrace');
        if (mounted) {
          setState(() {
            _uploadError = 'データベース監視の開始に失敗しました。';
          });
        }
      }
  }
  
  
  // 状態をリセットし、再挑戦できるようにする
  void _resetStateForRetry() {
      if(mounted) {
        setState(() {
          _selectedImage = null;
          _checkStatus = CheckStatus.notStarted;
          _isUploading = false;
          _isCheckingAutomatically = false;
          _hasAttemptedAutoCheck = false;
          _uploadError = '認証に失敗しました。再撮影してください。';
          _hasCalledApproved = false; // フラグをリセット
          _hasCalledRejected = false; // フラグをリセット
        });
      }
  }

  // MARK: - 2. カメラ/画像操作

  // WakeLockを有効化し、定期的に再有効化して保持する
  Future<void> _enableWakeLockWithKeepAlive() async {
    try {
      await WakelockPlus.enable();
      debugPrint('🔒 [CameraCheckPage] WakeLockを有効化しました（カメラ撮影開始前）');
      
      // 既存のタイマーを停止
      _wakelockKeepAliveTimer?.cancel();
      
      // 定期的にWakeLockを再有効化して保持する（1秒ごと）
      // これにより、バックグラウンドに移行してもアプリがキルされるのを防ぐ
      // 間隔を短くすることで、アプリがキルされる前にWakeLockを保持できる
      _wakelockKeepAliveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isCameraPicking) {
          // カメラ撮影が完了したらタイマーを停止
          timer.cancel();
          _wakelockKeepAliveTimer = null;
          return;
        }
        
        // WakeLockを再有効化
        WakelockPlus.enable().then((_) {
          debugPrint('🔒 [CameraCheckPage] WakeLockを再有効化しました（キープアライブ）');
        }).catchError((e) {
          debugPrint('⚠️ [CameraCheckPage] WakeLockの再有効化に失敗しました: $e');
        });
      });
    } catch (e) {
      debugPrint('⚠️ [CameraCheckPage] WakeLockの有効化に失敗しました: $e');
    }
  }
  
  // WakeLockを即座に再有効化（複数回試行して確実に保持する）
  void _renewWakeLockImmediately() {
    // 即座にWakeLockを再有効化
    WakelockPlus.enable().then((_) {
      debugPrint('🔒 [CameraCheckPage] WakeLockを再有効化しました（バックグラウンド移行時）');
    }).catchError((e) {
      debugPrint('⚠️ [CameraCheckPage] WakeLockの再有効化に失敗しました: $e');
    });
    
    // 0.25秒後にもう一度再有効化（確実に保持するため）
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_isCameraPicking && mounted) {
        WakelockPlus.enable().then((_) {
          debugPrint('🔒 [CameraCheckPage] WakeLockを再有効化しました（0.25秒後）');
        }).catchError((e) {
          debugPrint('⚠️ [CameraCheckPage] WakeLockの再有効化に失敗しました（0.25秒後）: $e');
        });
      }
    });
    
    // 0.5秒後にもう一度再有効化（確実に保持するため）
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isCameraPicking && mounted) {
        WakelockPlus.enable().then((_) {
          debugPrint('🔒 [CameraCheckPage] WakeLockを再有効化しました（0.5秒後）');
        }).catchError((e) {
          debugPrint('⚠️ [CameraCheckPage] WakeLockの再有効化に失敗しました（0.5秒後）: $e');
        });
      }
    });
    
    // 0.75秒後にもう一度再有効化（確実に保持するため）
    Future.delayed(const Duration(milliseconds: 750), () {
      if (_isCameraPicking && mounted) {
        WakelockPlus.enable().then((_) {
          debugPrint('🔒 [CameraCheckPage] WakeLockを再有効化しました（0.75秒後）');
        }).catchError((e) {
          debugPrint('⚠️ [CameraCheckPage] WakeLockの再有効化に失敗しました（0.75秒後）: $e');
        });
      }
    });
  }
  
  // WakeLockを無効化し、タイマーも停止する
  Future<void> _disableWakeLock() async {
    // タイマーを停止
    _wakelockKeepAliveTimer?.cancel();
    _wakelockKeepAliveTimer = null;
    
    // WakeLockを無効化
    try {
      await WakelockPlus.disable();
      debugPrint('🔓 [CameraCheckPage] WakeLockを無効化しました');
    } catch (e) {
      debugPrint('⚠️ [CameraCheckPage] WakeLockの無効化に失敗しました: $e');
    }
  }

  // フォトライブラリから画像を選択
  Future<void> _pickImageFromGallery() async {
    debugPrint('📷 [CameraCheckPage] _pickImageFromGallery() called');
    debugPrint('   - _isUploading: $_isUploading');
    debugPrint('   - _isCheckingAutomatically: $_isCheckingAutomatically');
    debugPrint('   - _isCameraPicking: $_isCameraPicking');
    debugPrint('   - mounted: $mounted');
    
    // 処理中の場合は何もしない
    if (_isUploading || _isCheckingAutomatically || _isCameraPicking) {
      debugPrint('⚠️ [CameraCheckPage] _pickImageFromGallery() skipped: 処理中です');
      return;
    }
    
    if (!mounted) {
      debugPrint('⚠️ [CameraCheckPage] Widget is not mounted, cannot pick image from gallery');
      return;
    }
    
    debugPrint('📷 [CameraCheckPage] フォトライブラリから画像を選択します...');
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // 85%の品質でメモリ使用量を削減
      ).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('⏱️ [CameraCheckPage] 画像選択がタイムアウトしました（5分経過）');
          return null;
        },
      );
      
      debugPrint('📷 [CameraCheckPage] ⭐⭐ pickImage()のFutureが完了しました ⭐⭐');
      debugPrint('   - image: ${image?.path ?? "null"}');
      debugPrint('   - mounted: $mounted');
      
      if (!mounted) {
        debugPrint('⚠️ [CameraCheckPage] Widget is not mounted after image selection');
        return;
      }
      
      if (image != null) {
        final File selectedFile = File(image.path);
        debugPrint('📷 [CameraCheckPage] 画像ファイルを取得しました: ${selectedFile.path}');
        debugPrint('📷 [CameraCheckPage] ファイルの存在確認: ${selectedFile.existsSync()}');
        
        if (!selectedFile.existsSync()) {
          debugPrint('❌ [CameraCheckPage] 画像ファイルが存在しません: ${selectedFile.path}');
          if (mounted) {
            setState(() {
              _uploadError = '画像ファイルが見つかりませんでした';
            });
          }
          return;
        }
        
        debugPrint('📷 [CameraCheckPage] Widget is mounted, updating state...');
        
        if (mounted) {
          setState(() {
            _selectedImage = selectedFile;
            _uploadError = null;
            _checkStatus = CheckStatus.notStarted; // 新しい写真を選んだらステータスリセット
            _hasAttemptedAutoCheck = false;
          });
          debugPrint('📷 [CameraCheckPage] State updated successfully');
          debugPrint('   - _selectedImage: ${_selectedImage?.path ?? "null"}');
          debugPrint('   - _checkStatus: $_checkStatus');
          debugPrint('📷 [CameraCheckPage] calling _checkImageAutomatically()...');
          
          // 画像が選ばれたら、すぐに自動認証を試みる
          _checkImageAutomatically();
        } else {
          debugPrint('⚠️ [CameraCheckPage] Widget is not mounted after state update');
        }
      } else {
        debugPrint('⚠️ [CameraCheckPage] 画像選択がキャンセルされました（image == null）');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [CameraCheckPage] _pickImageFromGallery() エラー: $e');
      debugPrint('   エラータイプ: ${e.runtimeType}');
      debugPrint('スタックトレース: $stackTrace');
      
      // エラーメッセージを設定
      String errorMessage = '画像選択中にエラーが発生しました';
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        errorMessage = '画像選択がタイムアウトしました。もう一度お試しください。';
      } else if (e.toString().contains('permission') || e.toString().contains('Permission')) {
        errorMessage = 'フォトライブラリの権限がありません。設定から権限を許可してください。';
      }
      
      if (mounted) {
        setState(() {
          _uploadError = errorMessage;
        });
      }
    }
  }

  // カメラを起動して画像を撮影
  Future<void> _takePhoto() async {
    debugPrint('📸 [CameraCheckPage] _takePhoto() called');
    debugPrint('   - _isUploading: $_isUploading');
    debugPrint('   - _isCheckingAutomatically: $_isCheckingAutomatically');
    debugPrint('   - _isCameraPicking: $_isCameraPicking');
    debugPrint('   - mounted: $mounted');
    
    // 処理中の場合は何もしない
    if (_isUploading || _isCheckingAutomatically || _isCameraPicking) {
      debugPrint('⚠️ [CameraCheckPage] _takePhoto() skipped: 処理中です');
      return;
    }
    
    if (!mounted) {
      debugPrint('⚠️ [CameraCheckPage] Widget is not mounted, cannot take photo');
      return;
    }
    
    // カメラ撮影中にWakeLockを有効化（アプリがバックグラウンドでキルされないようにする）
    // pickImage()を呼び出す前にWakeLockを有効化することで、アプリがキルされるのを防ぐ
    await _enableWakeLockWithKeepAlive();
    
    // バックグラウンドに移行していないか確認
    final currentState = WidgetsBinding.instance.lifecycleState;
    if (currentState != AppLifecycleState.resumed) {
      debugPrint('⚠️ [CameraCheckPage] アプリがバックグラウンドに移行しています。カメラ撮影をスキップします。');
      debugPrint('   - 現在のライフサイクル状態: $currentState');
      // WakeLockを無効化
      await _disableWakeLock();
      // フォトライブラリから画像を選択
      _pickImageFromGallery();
      return;
    }
    
    setState(() {
      _isCameraPicking = true;
      _wasCameraCancelled = false; // キャンセルフラグをリセット
    });
    
    // Androidのみ: Foreground Serviceを開始（カメラ撮影中にアプリがキルされるのを防ぐ）
    if (Platform.isAndroid) {
      try {
        await _foregroundServiceChannel.invokeMethod('startForegroundService');
        debugPrint('✅ [CameraCheckPage] Foreground Serviceを開始しました');
      } catch (e) {
        debugPrint('⚠️ [CameraCheckPage] Foreground Serviceの開始に失敗しました: $e');
        // Foreground Serviceの開始に失敗しても、カメラ撮影は続行
      }
    }
    
    debugPrint('📸 [CameraCheckPage] カメラを起動します...');
    debugPrint('📸 [CameraCheckPage] pickImage()を呼び出します（非同期処理開始）');
    
    try {
      debugPrint('📸 [CameraCheckPage] pickImage()を呼び出します（await開始）');
      
      // pickImage()を呼び出す直前にもう一度バックグラウンド移行をチェック
      final stateBeforePick = WidgetsBinding.instance.lifecycleState;
      if (stateBeforePick != AppLifecycleState.resumed) {
        debugPrint('⚠️ [CameraCheckPage] pickImage()呼び出し直前にバックグラウンド移行を検知');
        debugPrint('   - 現在のライフサイクル状態: $stateBeforePick');
        // カメラ撮影をキャンセル
        if (mounted) {
          setState(() {
            _wasCameraCancelled = true;
            _isCameraPicking = false;
          });
        }
        // WakeLockを無効化
        await _disableWakeLock();
        // フォトライブラリから画像を選択
        _pickImageFromGallery();
        return;
      }
      // タイムアウトを設定（5分）
      // メモリ使用量を削減するため、画像品質を85%に設定（デフォルトは100%）
      // また、最大幅・高さを制限してメモリ使用量を抑制
      // 注意: pickImage()を呼び出すと、ネイティブのカメラアプリが起動し、
      // Flutterアプリが一時的にバックグラウンドに移行します。これは正常な動作です。
      // ただし、カメラ撮影開始前にバックグラウンドに移行した場合はキャンセルします。
      // また、一部のデバイス（Kyoceraなど）では、カメラアプリがクラッシュする可能性があります。
      // その場合、エラーハンドリングでフォトライブラリから選択するようにフォールバックします。
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // 85%の品質でメモリ使用量を削減
        preferredCameraDevice: CameraDevice.rear, // 背面カメラを優先（一貫性のため）
      ).timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('⏱️ [CameraCheckPage] カメラ撮影がタイムアウトしました（5分経過）');
          
          // Androidのみ: Foreground Serviceを停止（タイムアウト時）
          // 注意: onTimeoutは同期関数なので、awaitは使用できない
          if (Platform.isAndroid) {
            _foregroundServiceChannel.invokeMethod('stopForegroundService').catchError((e) {
              debugPrint('⚠️ [CameraCheckPage] Foreground Serviceの停止に失敗しました（タイムアウト時）: $e');
            });
            debugPrint('✅ [CameraCheckPage] Foreground Serviceを停止しました（タイムアウト時）');
          }
          
          // タイムアウト時も状態をリセット
          if (mounted) {
            setState(() {
              _isCameraPicking = false;
            });
          }
          return null;
        },
      ).catchError((error) {
        debugPrint('❌ [CameraCheckPage] pickImage()でエラーが発生しました: $error');
        debugPrint('   エラータイプ: ${error.runtimeType}');
        debugPrint('   エラーメッセージ: ${error.toString()}');
        
        // Androidのみ: Foreground Serviceを停止（エラー時）
        // 注意: catchError内ではawaitは使用できないため、非同期で実行
        if (Platform.isAndroid) {
          _foregroundServiceChannel.invokeMethod('stopForegroundService').then((_) {
            debugPrint('✅ [CameraCheckPage] Foreground Serviceを停止しました（エラー時）');
          }).catchError((e) {
            debugPrint('⚠️ [CameraCheckPage] Foreground Serviceの停止に失敗しました（エラー時）: $e');
          });
        }
        
        // カメラアプリがクラッシュした可能性がある場合、フォトライブラリから選択する
        // 特にKyoceraデバイスなどでカメラアプリがクラッシュする場合がある
        if (mounted) {
          setState(() {
            _isCameraPicking = false;
            _uploadError = 'カメラアプリでエラーが発生しました。フォトライブラリから画像を選択します。';
          });
          // フォトライブラリから画像を選択
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _pickImageFromGallery();
            }
          });
        }
        return null;
      });
      
      // Androidのみ: Foreground Serviceを停止（カメラ撮影が完了したため）
      if (Platform.isAndroid) {
        try {
          await _foregroundServiceChannel.invokeMethod('stopForegroundService');
          debugPrint('✅ [CameraCheckPage] Foreground Serviceを停止しました');
        } catch (e) {
          debugPrint('⚠️ [CameraCheckPage] Foreground Serviceの停止に失敗しました: $e');
          // Foreground Serviceの停止に失敗しても、処理は続行
        }
      }
      
      // pickImage()のFutureが完了した後、キャンセルされているかチェック
      if (_wasCameraCancelled) {
        debugPrint('⚠️ [CameraCheckPage] pickImage()完了後にキャンセルフラグを検知。処理を中断します。');
        // WakeLockを無効化
        await _disableWakeLock();
        if (mounted) {
          setState(() {
            _isCameraPicking = false;
            _wasCameraCancelled = false;
          });
        }
        // フォトライブラリから画像を選択（フォアグラウンドに戻った時に実行される）
        return;
      }
      
      debugPrint('📸 [CameraCheckPage] ⭐⭐ pickImage()のFutureが完了しました ⭐⭐');
      debugPrint('   - image: ${image?.path ?? "null"}');
      debugPrint('   - mounted: $mounted');
      debugPrint('   - _wasCameraCancelled: $_wasCameraCancelled');
      
      // カメラ撮影がキャンセルされた場合、処理を中断
      if (_wasCameraCancelled) {
        debugPrint('⚠️ [CameraCheckPage] カメラ撮影がキャンセルされました。処理を中断します。');
        // WakeLockを無効化
        await _disableWakeLock();
        if (mounted) {
          setState(() {
            _isCameraPicking = false;
            _wasCameraCancelled = false;
          });
        }
        return;
      }
      
      // Widgetが破棄されている場合は、状態をリセットしない
      if (!mounted) {
        debugPrint('⚠️ [CameraCheckPage] Widget is not mounted after camera capture - disposing');
        // WakeLockを無効化
        await _disableWakeLock();
        return;
      }
      
      // カメラ撮影が完了したので、状態をリセット
      // WakeLockを無効化
      await _disableWakeLock();
      
      // 状態を更新（カメラ撮影フラグをfalseに）
      if (mounted) {
        setState(() {
          _isCameraPicking = false;
        });
        debugPrint('📸 [CameraCheckPage] _isCameraPicking = false に設定しました');
      } else {
        debugPrint('⚠️ [CameraCheckPage] Widget is not mounted after state reset');
        return;
      }
    
    if (image != null) {
      final File selectedFile = File(image.path);
        debugPrint('📸 [CameraCheckPage] 画像ファイルを取得しました: ${selectedFile.path}');
        debugPrint('📸 [CameraCheckPage] ファイルの存在確認: ${selectedFile.existsSync()}');
        
        if (!selectedFile.existsSync()) {
          debugPrint('❌ [CameraCheckPage] 画像ファイルが存在しません: ${selectedFile.path}');
          if (mounted) {
            setState(() {
              _uploadError = '画像ファイルが見つかりませんでした';
            });
          }
          return;
        }
        
        debugPrint('📸 [CameraCheckPage] Widget is mounted, updating state...');
      
      if(mounted) {
        setState(() {
          _selectedImage = selectedFile;
          _uploadError = null;
          _checkStatus = CheckStatus.notStarted; // 新しい写真を撮ったらステータスリセット
          _hasAttemptedAutoCheck = false;
        });
          debugPrint('📸 [CameraCheckPage] State updated successfully');
          debugPrint('   - _selectedImage: ${_selectedImage?.path ?? "null"}');
          debugPrint('   - _checkStatus: $_checkStatus');
          debugPrint('📸 [CameraCheckPage] calling _checkImageAutomatically()...');
        
        // Swiftコードの onChange(of: selectedImage) に相当するロジック
        // 画像が選ばれたら、すぐに自動認証を試みる
        _checkImageAutomatically();
        } else {
          debugPrint('⚠️ [CameraCheckPage] Widget is not mounted after state update');
        }
      } else {
        debugPrint('⚠️ [CameraCheckPage] カメラ撮影がキャンセルされました（image == null）');
        // カメラ撮影がキャンセルされた場合の処理
        // WakeLockを無効化
        try {
          await WakelockPlus.disable();
          debugPrint('🔓 [CameraCheckPage] WakeLockを無効化しました（キャンセル時）');
        } catch (e) {
          debugPrint('⚠️ [CameraCheckPage] WakeLockの無効化に失敗しました: $e');
        }
        // キャンセルされた場合も、_isCameraPickingをfalseにリセット
        if (mounted) {
          setState(() {
            _isCameraPicking = false;
            // エラーメッセージは表示しない（ユーザーがキャンセルしただけなので）
          });
          debugPrint('📸 [CameraCheckPage] キャンセル時の_isCameraPicking = false に設定しました');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [CameraCheckPage] _takePhoto() エラー: $e');
      debugPrint('   エラータイプ: ${e.runtimeType}');
      debugPrint('スタックトレース: $stackTrace');
      
      // エラー時もWakeLockを無効化
      await _disableWakeLock();
      
      // エラーメッセージを設定（ユーザーフレンドリーなメッセージ）
      String errorMessage = 'カメラ撮影中にエラーが発生しました';
      if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
        errorMessage = 'カメラ撮影がタイムアウトしました。もう一度お試しください。';
      } else if (e.toString().contains('permission') || e.toString().contains('Permission')) {
        errorMessage = 'カメラの権限がありません。設定から権限を許可してください。';
      } else if (e.toString().contains('camera') || e.toString().contains('Camera')) {
        errorMessage = 'カメラの起動に失敗しました。もう一度お試しください。';
      }
      
      if (mounted) {
        setState(() {
          _isCameraPicking = false;
          _uploadError = errorMessage;
        });
        debugPrint('📸 [CameraCheckPage] エラー時の_isCameraPicking = false に設定しました');
      } else {
        debugPrint('⚠️ [CameraCheckPage] Widget is not mounted after error');
      }
    }
  }

  // MARK: - 3. 自動認証とアップロード

  // Swiftの checkImageAutomatically に相当
  Future<void> _checkImageAutomatically() async {
    // 見本画像URLがない場合、自動認証はスキップし、管理者チェック待ちに移行する
    if (widget.problem.checkImageURL == null || _selectedImage == null) {
      if (widget.problem.checkImageURL == null) {
         setState(() {
            _uploadError = '見本画像がないため、自動認証をスキップし、アップロードを行います。';
         });
      }
      // 自動認証を試みることなく、管理者チェック待ちでアップロードを呼び出す
      return _uploadImage(newStatus: CheckStatus.waitingForCheck, needsAdminCheck: true);
    }
    
    // 既に処理中、または認証試行済みの場合はスキップ
    if (_isCheckingAutomatically || _hasAttemptedAutoCheck) return;

    setState(() {
      _isCheckingAutomatically = true;
      _hasAttemptedAutoCheck = true;
      _uploadError = null;
    });

    try {
      // ⚠️ **重要**: ここにMethod Channelを使った正確な画像比較ロジックが必要です
      // 以下の0.75はデモ用のスタブ値です。
      final double similarity = 0.75; 
      
      debugPrint('Auto check similarity: $similarity');

      if (similarity >= CameraCheckPage.similarityThreshold) {
        // 認証成功 -> 承認済みとしてアップロード
        await _uploadImage(newStatus: CheckStatus.approved, needsAdminCheck: false);
      } else {
        // 認証失敗 -> 管理者チェック待ちとしてアップロード
        await _uploadImage(newStatus: CheckStatus.waitingForCheck, needsAdminCheck: true);
        setState(() {
          _uploadError = '自動認証に失敗しました（類似度: ${(similarity * 100).toInt()}%）。管理者が確認します。';
        });
      }
    } on FirebaseServiceError catch (e) {
      setState(() {
        _uploadError = '自動認証/アップロード処理中にエラーが発生しました: ${e.message}';
      });
    } finally {
      if(mounted) {
        setState(() {
          _isCheckingAutomatically = false;
        });
      }
    }
  }
  
  // 画像をアップロードし、進捗を更新するメイン関数
  Future<void> _uploadImage({required CheckStatus newStatus, required bool needsAdminCheck}) async {
    debugPrint('📤 [CameraCheckPage] _uploadImage called');
    debugPrint('   - newStatus: $newStatus');
    debugPrint('   - needsAdminCheck: $needsAdminCheck');
    debugPrint('   - _selectedImage: ${_selectedImage?.path ?? "null"}');
    debugPrint('   - _isUploading: $_isUploading');
    
    if (_selectedImage == null || _isUploading) {
      debugPrint('⚠️ [CameraCheckPage] _uploadImage skipped: _selectedImage=${_selectedImage?.path ?? "null"}, _isUploading=$_isUploading');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      debugPrint('📤 [CameraCheckPage] Starting image upload...');
      // 1. 画像をFirebase Storageにアップロード（FirebaseServiceの機能を利用）
      final downloadUrl = await _firebaseService.uploadImage(
        _selectedImage!,
        widget.teamId,
        widget.eventId,
        widget.problemIndex,
      );
      debugPrint('✅ [CameraCheckPage] Image upload successful: $downloadUrl');

      // 2. 進捗を更新（Realtime Database）
      final newProgress = TeamProgress(
        teamId: widget.teamId,
        eventId: widget.eventId,
        currentProblemIndex: widget.problemIndex,
        checkStatus: newStatus,
        uploadedImageURL: downloadUrl,
        needsAdminCheck: needsAdminCheck,
      );

      debugPrint('📤 [CameraCheckPage] Updating team progress...');
      await _firebaseService.updateTeamProgress(newProgress);
      debugPrint('✅ [CameraCheckPage] Team progress updated successfully');
      
      // UIのローディング状態を解除
      if(mounted) {
        setState(() {
          _isUploading = false;
          _checkStatus = newStatus; // 状態を更新
        });
        
        debugPrint('📤 [CameraCheckPage] Status updated to: $newStatus');
        // 認証成功時はonApproved()を呼ばず、ユーザーが手動で「次へ進む」ボタンを押すまで画像認証ページに留まる
        // これにより、ユーザーが撮影した画像を確認できる
        if (newStatus == CheckStatus.rejected && !_hasCalledRejected) {
          _hasCalledRejected = true;
          debugPrint('❌ [CameraCheckPage] 認証失敗 - onRejected()を呼び出します');
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            try {
              widget.onRejected();
              _resetStateForRetry();
            } catch (e, stackTrace) {
              debugPrint('❌ [CameraCheckPage] onRejected()呼び出しエラー: $e');
              debugPrint('スタックトレース: $stackTrace');
            }
          }
        }
      }
    } on FirebaseServiceError catch (e) {
      if(mounted) {
        setState(() {
          _uploadError = 'アップロードに失敗しました: ${e.message}';
          _isUploading = false;
        });
      }
    }
  }


  // MARK: - 4. UI 構築

  @override
  Widget build(BuildContext context) {
    // エラーが発生している場合はエラー表示
    if (_uploadError != null && _uploadError!.contains('失敗')) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("カメラ認証"),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_uploadError!, style: const TextStyle(fontSize: 16, color: Colors.red)),
            ],
          ),
        ),
      );
    }
    
    return PopScope(
      canPop: !_isCameraPicking && !_isUploading && !_isCheckingAutomatically,
      onPopInvoked: (bool didPop) {
        if (didPop) {
          debugPrint('📸 [CameraCheckPage] PopScope: 画面が閉じられました');
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text("カメラ認証"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 撮影対象のカード (指示文と見本画像)
            _buildProblemInfoCard(),
            const SizedBox(height: 24),

            // 撮影済み画像またはプレースホルダー
            _buildImagePreviewSection(),
            const SizedBox(height: 24),

            // 認証状態のインジケータ
            _buildCheckStatusIndicator(),
            const SizedBox(height: 24),
            
            // エラーメッセージ
            if (_uploadError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('エラー: $_uploadError', style: const TextStyle(color: Colors.red, fontSize: 14)),
              ),
            
            // メインアクションボタン
            _buildActionButtons(),
          ],
        ),
        ),
      ),
    );
  }

  // 撮影対象のカードウィジェット
  Widget _buildProblemInfoCard() {
    // デバッグ: checkImageURLの値を確認
    debugPrint('📸 [CameraCheckPage] _buildProblemInfoCard');
    debugPrint('   - checkImageURL: ${widget.problem.checkImageURL}');
    debugPrint('   - checkImageURL is null: ${widget.problem.checkImageURL == null}');
    debugPrint('   - checkImageURL isEmpty: ${widget.problem.checkImageURL?.isEmpty ?? true}');
    
    // URLの検証と正規化
    String? imageUrl;
    if (widget.problem.checkImageURL != null) {
      final trimmedUrl = widget.problem.checkImageURL!.trim();
      if (trimmedUrl.isNotEmpty) {
        // URLの形式を検証
        try {
          final uri = Uri.parse(trimmedUrl);
          if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
            imageUrl = trimmedUrl;
            debugPrint('✅ [CameraCheckPage] 有効な画像URL: $imageUrl');
          } else {
            debugPrint('⚠️ [CameraCheckPage] 無効なURLスキーム: $trimmedUrl');
          }
        } catch (e) {
          debugPrint('❌ [CameraCheckPage] URL解析エラー: $e');
          debugPrint('   - 元のURL: $trimmedUrl');
        }
      }
    }
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("撮影対象のミッション", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            
            if (widget.problem.checkText != null && widget.problem.checkText!.isNotEmpty)
              Text("指示: ${widget.problem.checkText!}", style: const TextStyle(fontSize: 16)),
            
            const SizedBox(height: 16),
            
            // checkImageURLのチェックを改善
            if (imageUrl != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("見本画像:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 8),
                  // キャッシュ付きネットワーク画像ローダーを使用
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        height: 300,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          placeholder: (context, url) => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                          debugPrint('❌ [CameraCheckPage] 画像読み込みエラー');
                          debugPrint('   - URL: $url');
                          debugPrint('   - エラータイプ: ${error.runtimeType}');
                          debugPrint('   - エラー詳細: $error');
                          
                          // エラーの種類に応じたメッセージ
                          String errorMessage = '画像の読み込みに失敗しました';
                          if (error is Exception) {
                            final errorStr = error.toString().toLowerCase();
                            if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
                              errorMessage = 'タイムアウト: 画像の読み込みに時間がかかりすぎました';
                            } else if (errorStr.contains('network') || errorStr.contains('connection')) {
                              errorMessage = 'ネットワークエラー: 接続を確認してください';
                            } else if (errorStr.contains('404') || errorStr.contains('not found')) {
                              errorMessage = '画像が見つかりません';
                            } else if (errorStr.contains('403') || errorStr.contains('forbidden')) {
                              errorMessage = 'アクセス権限がありません';
                            }
                          }
                          
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image, size: 50, color: Colors.red),
                                const SizedBox(height: 8),
                                Text(
                                  errorMessage,
                                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    'URL: ${url.length > 50 ? "${url.substring(0, 50)}..." : url}',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                          },
                          fit: BoxFit.contain,
                          width: double.infinity,
                          httpHeaders: const {
                            'Accept': 'image/*',
                          },
                          maxWidthDiskCache: 1000 * 1000 * 10, // 10MB
                          maxHeightDiskCache: 1000 * 1000 * 10, // 10MB
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.problem.checkImageURL == null || widget.problem.checkImageURL!.trim().isEmpty
                            ? "見本画像が設定されていません"
                            : "見本画像のURLが無効です",
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // 画像プレビューセクション
  Widget _buildImagePreviewSection() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: _selectedImage == null ? Border.all(color: Colors.grey, width: 2) : null,
      ),
      child: _selectedImage == null
          ? const Center(
              child: Text(
                "撮影した写真がここに表示されます",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(_selectedImage!, fit: BoxFit.cover),
            ),
    );
  }

  // 認証状態表示ウィジェット
  Widget _buildCheckStatusIndicator() {
    Color color;
    String text;
    IconData icon;
    bool showProgress = false;

    switch (_checkStatus) {
      case CheckStatus.notStarted:
        // 写真撮影前は非表示
        return const SizedBox.shrink(); 
      case CheckStatus.waitingForCheck:
        color = Colors.orange;
        text = "管理者チェック待ち...";
        icon = Icons.access_time_filled;
        showProgress = true;
        break;
      case CheckStatus.approved:
        color = Colors.green;
        text = "✅ 認証クリア！";
        icon = Icons.check_circle_sharp;
        break;
      case CheckStatus.rejected:
        color = Colors.red;
        text = "❌ 認証失敗 - 再撮影が必要です";
        icon = Icons.cancel;
        break;
      default:
        // すべてのケースをカバーするためのデフォルト
        color = Colors.grey;
        text = "不明な状態";
        icon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          showProgress ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : Icon(icon, color: color),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ],
      ),
    );
  }
  
  // アクションボタンセクション
  Widget _buildActionButtons() {
    final bool isBusy = _isUploading || _isCheckingAutomatically || _isCameraPicking;
    
    // 1. 写真が未撮影の場合
    if (_selectedImage == null) {
      return ElevatedButton.icon(
        onPressed: isBusy ? null : _takePhoto,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text("カメラを起動して撮影", style: TextStyle(color: Colors.white, fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } 

    // 2. 写真撮影済み & 承認待ち / 失敗の状態
    if (_checkStatus != CheckStatus.approved) {
      return Column(
        children: [
          // 自動認証 / 管理者チェック待ちボタン
          ElevatedButton.icon(
            onPressed: isBusy ? null : _checkImageAutomatically,
            icon: isBusy 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send, color: Colors.white),
            label: Text(
              _isCameraPicking
                  ? "カメラ撮影中..."
                  : (_isCheckingAutomatically
                  ? "自動認証中..."
                      : (_isUploading ? "アップロード中..." : "認証を試みる / 送信")),
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isBusy ? Colors.grey : Colors.green,
              padding: const EdgeInsets.all(18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          // 再撮影ボタン
          OutlinedButton(
            onPressed: isBusy ? null : _takePhoto,
            child: const Text("別の写真を撮る (再撮影)"),
          ),
        ],
      );
    }
    
    // 3. 承認済みの場合は「次へ進む」ボタンを表示
    return ElevatedButton.icon(
      onPressed: () {
        debugPrint('✅ [CameraCheckPage] 「次へ進む」ボタンが押されました');
        if (!_hasCalledApproved) {
          _hasCalledApproved = true;
          try {
            widget.onApproved(); // GameView側で画面を閉じて次の処理を行う
            debugPrint('✅ [CameraCheckPage] onApproved()呼び出し成功');
          } catch (e, stackTrace) {
            debugPrint('❌ [CameraCheckPage] onApproved()呼び出しエラー: $e');
            debugPrint('スタックトレース: $stackTrace');
          }
        }
      },
      icon: const Icon(Icons.arrow_forward, color: Colors.white),
      label: const Text("次へ進む", style: TextStyle(color: Colors.white, fontSize: 18)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}