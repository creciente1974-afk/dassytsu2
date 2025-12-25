import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

// サービスとモデルのインポート
import '../../firebase_service.dart';
import '../services/firebase_service_error.dart';

class MediaUploadPage extends StatefulWidget {
  // Swiftの @Binding var mediaURL: String に相当
  final ValueNotifier<String> mediaURLNotifier; 
  
  final String eventId;
  final String problemId;

  const MediaUploadPage({
    required this.mediaURLNotifier,
    required this.eventId,
    required this.problemId,
    super.key,
  });

  @override
  State<MediaUploadPage> createState() => _MediaUploadPageState();
}

class _MediaUploadPageState extends State<MediaUploadPage> {
  // MARK: - Properties (State変数の定義)
  
  // 選択されたメディアファイル情報
  File? _selectedMediaFile;
  String? _mimeType; 

  // 動画プレイヤー関連
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  bool _isUploading = false;
  String? _uploadError;
  
  final FirebaseService _firebaseService = FirebaseService();

  // MARK: - Lifecycle
  
  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }
  
  // MARK: - Media Selection (Swiftの loadSelectedItem に相当)

  Future<void> _pickMedia() async {
    // 動画と画像の両方を選択可能にする
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'mp4', 'mov'],
    );

    if (result != null && result.files.single.path != null) {
      final path = result.files.single.path!;
      final mime = result.files.single.extension;
      
      setState(() {
        _selectedMediaFile = File(path);
        _mimeType = mime;
      });
      
      // 動画の場合、プレビューを初期化
      if (_isMediaVideo(mime)) {
        await _initializeVideoPlayer();
      } else {
        // 画像の場合、プレイヤーを破棄
        _disposeVideoPlayer();
      }
    }
  }

  bool _isMediaVideo(String? mime) {
    if (mime == null) return false;
    final lower = mime.toLowerCase();
    return lower == 'mp4' || lower == 'mov' || lower == 'avi';
  }

  // MARK: - Video Player Management

  Future<void> _initializeVideoPlayer() async {
    _disposeVideoPlayer();
    
    if (_selectedMediaFile != null) {
      _videoPlayerController = VideoPlayerController.file(_selectedMediaFile!);
      await _videoPlayerController!.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        autoInitialize: true,
        looping: false,
        allowFullScreen: false,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(errorMessage, style: const TextStyle(color: Colors.white)),
          );
        },
      );
    }
    setState(() {});
  }

  void _disposeVideoPlayer() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }
  
  // MARK: - Upload Logic (Swiftの uploadMedia に相当)

  void _uploadMedia() async {
    if (_isUploading || _selectedMediaFile == null) return;
    
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      String uploadedUrl;
      final file = _selectedMediaFile!;

      if (_isMediaVideo(_mimeType)) {
        // 動画のアップロード (FirebaseService.uploadMediaVideo は既に実装されているはず)
        uploadedUrl = await _firebaseService.uploadMediaVideo(
          file, 
          widget.eventId, 
          widget.problemId,
        );
      } else {
        // 画像のアップロード（問題画像の場合）
        uploadedUrl = await _firebaseService.uploadReferenceImage(
          file, 
          widget.eventId, 
          widget.problemId,
        );
      }

      if (mounted) {
        // 成功したらmediaURLを更新し、画面を閉じる
        widget.mediaURLNotifier.value = uploadedUrl;
        setState(() {
          _isUploading = false;
        });
        Navigator.of(context).pop();
      }
    } on FirebaseServiceError catch (e) {
      _handleError(e.message);
    } catch (e) {
      _handleError('アップロードに失敗しました: $e');
    }
  }
  
  void _handleError(String message) {
    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadError = message;
      });
      // エラーアラート表示 (Swiftの .alert に相当)
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAlert());
    }
  }
  
  // MARK: - UI Build
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Swiftの navigationTitle と navigationBarTitleDisplayMode(.inline) に相当
      appBar: AppBar(
        title: const Text("メディア設定"),
        actions: [
          // Swiftの ToolbarItem(placement: .navigationBarTrailing) Button("閉じる") に相当
          TextButton(
            onPressed: _isUploading ? null : () => Navigator.of(context).pop(),
            child: const Text("閉じる"),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          // Swiftの Form に相当するセクション風のレイアウト
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMediaSelectionSection(),
              const SizedBox(height: 32),
              if (_selectedMediaFile != null)
                _buildUploadButtonSection(),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - メディア選択セクション
  
  Widget _buildMediaSelectionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("メディアを選択", style: TextStyle(
          color: Theme.of(context).colorScheme.primary, 
          fontWeight: FontWeight.bold,
          fontSize: 16,
        )),
        const SizedBox(height: 8),
        
        // PhotosPicker(selection: ...) に相当するボタン
        GestureDetector(
          onTap: _isUploading ? null : _pickMedia,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100, // Color(.systemGray6) に近い
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _buildMediaPreview(),
          ),
        ),
      ],
    );
  }

  // MARK: - メディアプレビュー
  
  Widget _buildMediaPreview() {
    if (_chewieController != null) {
      // 動画プレビュー (VideoPlayerに相当)
      return Column(
        children: [
          AspectRatio(
            aspectRatio: _chewieController!.aspectRatio ?? 16 / 9,
            child: Chewie(controller: _chewieController!),
          ),
          const SizedBox(height: 8),
          Text(
            '動画ファイル (${_selectedMediaFile!.path.split('/').last})',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          )
        ],
      );
    } else if (_selectedMediaFile != null) {
      // 画像プレビュー (Image(uiImage: unwrappedImage) に相当)
      return Column(
        children: [
          Image.file(
            _selectedMediaFile!,
            fit: BoxFit.contain,
            height: 200,
          ),
          const SizedBox(height: 8),
          Text(
            '画像ファイル (${_selectedMediaFile!.path.split('/').last})',
            style: TextStyle(color: Theme.of(context).colorScheme.secondary),
          )
        ],
      );
    } else {
      // プレースホルダー (VStack, Image(systemName: "photo.on.rectangle") に相当)
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library, // photo.on.rectangle の代替
            size: 50,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            "写真または動画を選択",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            "画像または動画ファイルを選択してください",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      );
    }
  }

  // MARK: - アップロードボタンセクション
  
  Widget _buildUploadButtonSection() {
    // Section { Button(action: uploadMedia) } に相当
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUploading ? null : _uploadMedia,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isUploading 
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ProgressView() に相当
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    const Text("アップロード中..."),
                  ],
                )
              : const Text("アップロードして使用", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
  
  // MARK: - Alert
  
  void _showAlert() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("エラー"),
          content: Text(_uploadError ?? "不明なエラーが発生しました"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }
}