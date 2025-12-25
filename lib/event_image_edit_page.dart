// event_image_edit_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'lib/models/event.dart'; // Eventモデル
import 'firebase_service.dart'; // FirebaseService


class EventImageEditPage extends StatefulWidget {
  // @Binding var event: Event の代わり
  final Event initialEvent;
  final ValueChanged<Event> onEventUpdated;

  const EventImageEditPage({
    super.key,
    required this.initialEvent,
    required this.onEventUpdated,
  });

  @override
  State<EventImageEditPage> createState() => _EventImageEditPageState();
}

class _EventImageEditPageState extends State<EventImageEditPage> {
  late Event _currentEvent; // 編集中のイベント状態
  File? _selectedImageFile; // 選択されたローカル画像ファイル
  String? _cardImageURL; // Firebaseにアップロード済みのURL
  bool _isUploading = false;
  String? _uploadError;
  bool _showErrorAlert = false;

  final FirebaseService _firebaseService = FirebaseService();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.initialEvent;
    _cardImageURL = widget.initialEvent.cardImageUrl;
  }

  // SwiftUIの PhotosPicker の onChange(of: selectedItem) に相当
  Future<void> _pickImage() async {
    if (_isUploading) return;
    
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
        // 既存のURLはクリア（新しい画像を選択したため）
        if (_cardImageURL != null && _cardImageURL!.isNotEmpty) {
          _cardImageURL = null;
        }
      });
    }
  }

  // SwiftUIの uploadImage() に相当
  Future<void> _uploadImage() async {
    if (_selectedImageFile == null) {
      setState(() {
        _uploadError = "画像が選択されていません";
        _showErrorAlert = true;
      });
      return;
    }

    final eventId = _currentEvent.id;
    setState(() {
      _isUploading = true;
      _uploadError = null;
    });

    try {
      final imageURL = await _firebaseService.uploadEventCardImage(
        _selectedImageFile!,
        eventId: eventId,
      );

      setState(() {
        _cardImageURL = imageURL;
        _isUploading = false;
        _selectedImageFile = null; // アップロード完了後、ローカルファイルはクリア
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = "画像のアップロードに失敗しました: ${e.toString()}";
        _showErrorAlert = true;
      });
    }
  }

  // SwiftUIの saveImage() に相当
  Future<void> _saveImage() async {
    // 1. 画像が選択されているがまだアップロードされていない場合は、先にアップロード
    if (_selectedImageFile != null && (_cardImageURL == null || _cardImageURL!.isEmpty)) {
      setState(() {
        _isUploading = true;
        _uploadError = null;
      });

      try {
        final eventId = _currentEvent.id;
        final imageURL = await _firebaseService.uploadEventCardImage(
          _selectedImageFile!,
          eventId: eventId,
        );
        
        // アップロード完了後、状態を更新し、保存処理を続行
        setState(() {
          _cardImageURL = imageURL;
          _isUploading = false;
          _selectedImageFile = null;
        });

        await _continueSaving();

      } catch (e) {
        setState(() {
          _isUploading = false;
          _uploadError = "画像のアップロードに失敗しました: ${e.toString()}";
          _showErrorAlert = true;
        });
      }
      return;
    }

    // 2. アップロード済みまたは画像がない場合は、直接保存
    await _continueSaving();
  }

  // SwiftUIの continueSaving() に相当
  Future<void> _continueSaving() async {
    // イベントを更新
    final updatedEvent = _currentEvent.copyWith(
      cardImageUrl: _cardImageURL,
    );

    // Firebaseに保存
    try {
      // パスコードはUserDefaultから取得するなど、実際のロジックに合わせる
      const passcode = "samplePasscode"; 
      await _firebaseService.saveEvent(updatedEvent);

      widget.onEventUpdated(updatedEvent); // 親ウィジェットに更新を通知
      if (mounted) {
        Navigator.of(context).pop(); // dismiss() の代わり
      }
    } catch (e) {
      setState(() {
        _uploadError = "保存に失敗しました: ${e.toString()}";
        _showErrorAlert = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("画像編集"),
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(), // キャンセル
          child: const Text("キャンセル"),
        ),
        actions: [
          TextButton(
            onPressed: _isUploading ? null : _saveImage,
            child: const Text("保存"),
          ),
        ],
      ),
      body: _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Section(header: Text("イベントカード画像")) の代わり
        Text(
          "イベントカード画像",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),

        // 画像表示エリア (SwiftUIの AsyncImage, Image(uiImage: selectedImage), VStack(spacing: 16) の条件分岐)
        _buildImageDisplay(),
        const SizedBox(height: 16),

        // 写真を選択 (PhotosPicker の代わり)
        ListTile(
          title: const Text("写真を選択"),
          trailing: _isUploading ? const CircularProgressIndicator.adaptive() : const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: _isUploading ? null : _pickImage,
          contentPadding: EdgeInsets.zero,
        ),
        const Divider(height: 1),

        // 画像をアップロードボタン
        if (_selectedImageFile != null && (_cardImageURL == null || _cardImageURL!.isEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ElevatedButton(
              onPressed: _isUploading ? null : _uploadImage,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isUploading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator.adaptive(strokeWidth: 2),
                        SizedBox(width: 8),
                        Text("アップロード中..."),
                      ],
                    )
                  : const Text("画像をアップロード"),
            ),
          ),

        // 画像を削除ボタン
        if (_cardImageURL != null && _cardImageURL!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextButton(
              onPressed: _isUploading ? null : () {
                setState(() {
                  _cardImageURL = null;
                  _selectedImageFile = null;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 48),
              ),
              child: const Text("画像を削除"),
            ),
          ),
        
        const SizedBox(height: 32),
        // Section(footer: Text("...")) の代わり
        Text(
          "イベント一覧とイベント管理ページのカードに表示される画像を設定できます。",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
  
  // 画像表示ロジック
  Widget _buildImageDisplay() {
    if (_cardImageURL != null && _cardImageURL!.isNotEmpty) {
      // 1. 既存のURLがある場合 (AsyncImage の success に相当)
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: _cardImageURL!,
          fit: BoxFit.cover,
          height: 200,
          width: double.infinity,
          placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
          errorWidget: (context, url, error) => _buildErrorOrEmptyImage(
            text: "画像の読み込みに失敗しました",
            icon: Icons.error_outline,
          ),
        ),
      );
    } else if (_selectedImageFile != null) {
      // 2. ローカル画像が選択されている場合 (Image(uiImage: selectedImage) に相当)
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _selectedImageFile!,
          fit: BoxFit.cover,
          height: 200,
          width: double.infinity,
        ),
      );
    } else {
      // 3. 画像がない場合 (VStack(spacing: 16) に相当)
      return _buildErrorOrEmptyImage(
        text: "画像が設定されていません",
        icon: Icons.photo,
      );
    }
  }

  // 画像がない、またはエラー時のプレースホルダー
  Widget _buildErrorOrEmptyImage({required String text, required IconData icon}) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 50,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

// プレビューの代わり (main.dart などから呼び出す想定)
class EventImageEditPreview extends StatelessWidget {
  EventImageEditPreview({super.key});

  final Event sampleEvent = Event(
    id: 'sample-uuid',
    name: 'サンプルイベント',
    problems: [],
    duration: 60,
    records: [],
    cardImageUrl: null, // 初期値は画像なし
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EventImageEditPage(
        initialEvent: sampleEvent,
        onEventUpdated: (updatedEvent) {
          print("Event updated: ${updatedEvent.cardImageUrl}");
          // 実際は状態管理 (Provider/Riverpod) でEventを更新
        },
      ),
    );
  }
}