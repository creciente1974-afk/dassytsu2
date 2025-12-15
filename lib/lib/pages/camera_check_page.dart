import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

// サービスとモデルのインポート
import '../models/problem.dart';
import '../lib/models/team_progress.dart'; // CheckStatusとTeamProgressをインポート
import '../../../firebase_service.dart';
import '../../../lib/services/firebase_service_error.dart';

// 仮の画像比較ロジック（Method Channelの代替スタブ）
// 実際にはネイティブコードのVisionで実装されます。
// 

class CameraCheckPage extends StatefulWidget {
  final Problem problem;
  final String eventId;
  final int problemIndex;
  final String teamId;
  
  // 認証成功・失敗時のコールバック（画面遷移などに使用）
  final VoidCallback onApproved;
  final VoidCallback onRejected;
  
  // 自動認証の閾値（Swiftコードのロジックに合わせる）
  static const double similarityThreshold = 0.7;

  const CameraCheckPage({
    required this.problem,
    required this.eventId,
    required this.problemIndex,
    required this.teamId,
    required this.onApproved,
    required this.onRejected,
    super.key,
  });

  @override
  State<CameraCheckPage> createState() => _CameraCheckPageState();
}

class _CameraCheckPageState extends State<CameraCheckPage> {
  // MARK: - サービスとコントローラー
  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();
  
  // MARK: - UIの状態変数
  File? _selectedImage;                  // 撮影したローカル画像ファイル
  CheckStatus _checkStatus = CheckStatus.notStarted; // 現在の認証ステータス
  bool _isUploading = false;             // アップロード中フラグ
  bool _isCheckingAutomatically = false; // 自動認証処理中フラグ
  bool _hasAttemptedAutoCheck = false;   // 自動認証を試みたか
  String? _uploadError;                  // エラーメッセージ

  // MARK: - Firebaseの監視
  StreamSubscription<TeamProgress?>? _progressSubscription;
  
  @override
  void initState() {
    super.initState();
    _loadInitialProgressAndStartObserving();
    // Swiftコードでは見本画像をダウンロードしていましたが、ここでは
    // 自動認証のスタブを使用するため、ダウンロードロジックはスキップします。
  }

  @override
  void dispose() {
    // 画面が閉じられるときにFirebaseの監視を停止する
    _progressSubscription?.cancel();
    super.dispose();
  }

  // MARK: - 1. Firebase 進捗の監視と初期化

  // Swiftの loadInitialProgress に相当するロジック
  void _loadInitialProgressAndStartObserving() {
    _progressSubscription?.cancel();

    // 監視を開始
    _progressSubscription = _firebaseService
        .observeTeamProgress(widget.teamId, widget.eventId)
        .listen((progress) async {
      
      // 1. データがない場合、初期データを作成し、Realtime Databaseに書き込む
      if (progress == null || progress.currentProblemIndex != widget.problemIndex) {
        final initialProgress = TeamProgress(
          teamId: widget.teamId,
          eventId: widget.eventId,
          currentProblemIndex: widget.problemIndex,
          checkStatus: CheckStatus.notStarted,
        );
        // DBに初期状態を書き込み（非同期なので待たない）
        await _firebaseService.updateTeamProgress(initialProgress); 
        return;
      }

      // 2. データが現在の問題と一致する場合、UIの状態を更新
      if (_checkStatus != progress.checkStatus && mounted) {
        setState(() {
          _checkStatus = progress.checkStatus;
        });

        // 状態に応じた後続処理
        if (progress.checkStatus == CheckStatus.approved) {
          widget.onApproved(); // 承認されたら画面遷移などのコールバック
        } else if (progress.checkStatus == CheckStatus.rejected) {
          widget.onRejected(); // 拒否されたら（必要に応じて画面遷移またはリセット）
          
          // Rejectedの場合、再挑戦を促すためにUIの状態をリセット
          _resetStateForRetry();
        }
      }
    });
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
        });
      }
  }

  // MARK: - 2. カメラ/画像操作

  // カメラを起動して画像を撮影
  Future<void> _takePhoto() async {
    // 処理中の場合は何もしない
    if (_isUploading || _isCheckingAutomatically) return;
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // 画像品質を設定
      );
      
      if (image != null) {
        final File selectedFile = File(image.path);
        
        // ファイルが存在するか確認
        if (await selectedFile.exists()) {
          if(mounted) {
            setState(() {
              _selectedImage = selectedFile;
              _uploadError = null;
              _checkStatus = CheckStatus.notStarted; // 新しい写真を撮ったらステータスリセット
              _hasAttemptedAutoCheck = false;
            });
            
            // 撮影後は自動認証を行わず、ユーザーが「認証」ボタンを押下するまで待つ
          }
        } else {
          if(mounted) {
            setState(() {
              _uploadError = '撮影した画像ファイルが見つかりませんでした。';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [CameraCheckPage] カメラエラー: $e');
      if(mounted) {
        setState(() {
          _uploadError = 'カメラの起動に失敗しました: ${e.toString()}';
        });
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
    if (_selectedImage == null || _isUploading) return;

    setState(() {
      _isUploading = true;
    });

    try {
      // 1. 画像をFirebase Storageにアップロード（FirebaseServiceの機能を利用）
      final downloadUrl = await _firebaseService.uploadImage(
        _selectedImage!,
        widget.teamId,
        widget.eventId,
        widget.problemIndex,
      );

      // 2. 進捗を更新（Realtime Database）
      final newProgress = TeamProgress(
        teamId: widget.teamId,
        eventId: widget.eventId,
        currentProblemIndex: widget.problemIndex,
        checkStatus: newStatus,
        uploadedImageURL: downloadUrl,
        needsAdminCheck: needsAdminCheck,
      );

      await _firebaseService.updateTeamProgress(newProgress);
      
      // UIのローディング状態を解除（_loadInitialProgressAndStartObservingが最終的にUIを更新する）
      if(mounted) {
        setState(() {
          _isUploading = false;
        });
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
    return Scaffold(
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
    );
  }

  // 撮影対象のカードウィジェット
  Widget _buildProblemInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("認証チェック", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            
            // 認証チェック画像を表示
            if (widget.problem.checkImageURL != null && widget.problem.checkImageURL!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "認証チェック画像:",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                  ),
                  const SizedBox(height: 12),
                  // キャッシュ付きネットワーク画像ローダーを使用
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: widget.problem.checkImageURL!,
                        placeholder: (context, url) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20.0),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Icon(Icons.broken_image, size: 50, color: Colors.red),
                        ),
                        fit: BoxFit.contain,
                        height: 250,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "この画像と同じものを撮影してください",
                    style: TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "認証チェック画像が設定されていません",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            
            if (widget.problem.checkText != null && widget.problem.checkText!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 20),
              Text("指示: ${widget.problem.checkText!}", style: const TextStyle(fontSize: 16)),
            ],
          ],
        ),
      ),
    );
  }
  
  // 画像プレビューセクション
  Widget _buildImagePreviewSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "撮影した画像",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
            border: _selectedImage == null 
                ? Border.all(color: Colors.grey, width: 2) 
                : Border.all(color: Colors.green, width: 2),
          ),
          child: _selectedImage == null
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text(
                        "撮影した写真がここに表示されます",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_selectedImage!, fit: BoxFit.cover),
                ),
        ),
      ],
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
    final bool isBusy = _isUploading || _isCheckingAutomatically;
    
    // 1. 写真が未撮影の場合 - 「撮影して認証」ボタンを表示
    if (_selectedImage == null) {
      return ElevatedButton.icon(
        onPressed: isBusy ? null : _takePhoto,
        icon: const Icon(Icons.camera_alt, color: Colors.white),
        label: const Text("撮影して認証", style: TextStyle(color: Colors.white, fontSize: 18)),
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
          // 認証ボタン（撮影後に表示）
          ElevatedButton.icon(
            onPressed: isBusy ? null : _checkImageAutomatically,
            icon: isBusy 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.verified, color: Colors.white),
            label: Text(
              _isCheckingAutomatically
                  ? "認証中..."
                  : (_isUploading ? "アップロード中..." : "認証する"),
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
    
    // 3. 承認済みの場合はボタンを非表示
    return const SizedBox.shrink();
  }
}