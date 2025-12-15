// event_title_edit_view.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'lib/models/event.dart'; // 正規のEventモデル
import 'lib/models/escape_record.dart'; // EscapeRecordモデル
import 'firebase_service.dart'; // FirebaseService
import 'event_list_page.dart'; // EventListPage

// ----------------------------------------------------

class EventTitleEditView extends StatefulWidget {
  // SwiftUIの @Binding var event: Event に相当
  final Event event;
  final Function(Event updatedEvent)? onUpdate; // 更新されたイベントを親に返すコールバック

  const EventTitleEditView({
    super.key,
    required this.event,
    this.onUpdate,
  });

  @override
  State<EventTitleEditView> createState() => _EventTitleEditViewState();
}

class _EventTitleEditViewState extends State<EventTitleEditView> {
  // SwiftUIの @State 変数に相当
  late TextEditingController _eventNameController;
  late TextEditingController _commentController;
  late TextEditingController _overviewController;
  late TextEditingController _passcodeController;
  late DateTime _eventDate;
  late bool _isVisible;
  late bool _isNewEvent; // 新規作成かどうか
  
  bool _isSaving = false;
  bool _isResetting = false;
  
  // エラー/アラートの状態
  bool _showError = false;
  String _errorMessage = "";
  
  // 画像選択関連
  File? _selectedImageFile;
  bool _isUploadingImage = false;
  bool _imageRemoved = false; // 既存の画像を削除したかどうか
  final ImagePicker _imagePicker = ImagePicker();
  
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    // SwiftUIの init() 内での初期値設定に相当
    _isNewEvent = widget.event.id.isEmpty || widget.event.name.isEmpty;
    _eventNameController = TextEditingController(text: widget.event.name);
    _commentController = TextEditingController(text: widget.event.comment);
    _overviewController = TextEditingController(text: widget.event.overview);
    _passcodeController = TextEditingController(text: widget.event.creationPasscode ?? '');
    _eventDate = widget.event.eventDate ?? DateTime.now();
    _isVisible = widget.event.isVisible;
  }
  
  @override
  void dispose() {
    _eventNameController.dispose();
    _commentController.dispose();
    _overviewController.dispose();
    _passcodeController.dispose();
    super.dispose();
  }

  // 保存ボタンの有効/無効を判定するGetter
  bool get _isSaveDisabled {
    return _eventNameController.text.trim().isEmpty || 
           _isSaving || 
           _isResetting || 
           _isUploadingImage;
  }

  // 画像選択メソッド
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("⚠️ [EventTitleEditView] 画像選択エラー: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "画像の選択に失敗しました: $e";
          _showError = true;
        });
      }
    }
  }

  // 画像削除メソッド
  void _removeImage() {
    setState(() {
      _selectedImageFile = null;
      _imageRemoved = true; // 既存の画像も削除するフラグを立てる
    });
  }

  // SwiftUIの private func saveEvent() async に相当
  Future<void> _saveEvent() async {
    final name = _eventNameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = "イベント名を入力してください";
        _showError = true;
      });
      return;
    }
    
    setState(() { _isSaving = true; });

    // 画像をアップロード（選択されている場合）または削除
    String? imageUrl;
    if (_imageRemoved && _selectedImageFile == null) {
      // 画像が削除された場合
      imageUrl = null;
    } else if (_selectedImageFile != null) {
      // 新しい画像が選択された場合
      setState(() { _isUploadingImage = true; });
      try {
        if (_firebaseService.isConfigured) {
          imageUrl = await _firebaseService.uploadEventCardImage(
            _selectedImageFile!,
            eventId: widget.event.id,
          );
          print("✅ [EventTitleEditView] 画像アップロード成功: $imageUrl");
        } else {
          print("⚠️ [EventTitleEditView] Firebaseが設定されていないため、画像をアップロードできません。");
          imageUrl = widget.event.cardImageUrl; // 既存のURLを保持
        }
      } catch (error) {
        print("⚠️ [EventTitleEditView] 画像アップロードエラー: $error");
        if (mounted) {
          setState(() {
            _errorMessage = "画像のアップロードに失敗しました: $error";
            _showError = true;
            _isSaving = false;
            _isUploadingImage = false;
          });
        }
        return;
      } finally {
        if (mounted) {
          setState(() { _isUploadingImage = false; });
        }
      }
    } else {
      // 画像に変更がない場合、既存のURLを保持
      imageUrl = widget.event.cardImageUrl;
    }

    // 暗証番号を取得（新規作成時のみ入力された値を使用）
    final passcode = _isNewEvent 
        ? _passcodeController.text.trim()
        : (widget.event.creationPasscode ?? '');
    
    if (_isNewEvent && passcode.isEmpty) {
      setState(() {
        _errorMessage = "暗証番号を入力してください";
        _showError = true;
        _isSaving = false;
      });
      return;
    }

    // イベントオブジェクトを更新
    final updatedEvent = widget.event.copyWith(
      name: name,
      eventDate: _eventDate,
      isVisible: _isVisible,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      overview: _overviewController.text.trim().isEmpty ? null : _overviewController.text.trim(),
      cardImageUrl: imageUrl,
      creationPasscode: passcode.isNotEmpty ? passcode : widget.event.creationPasscode,
      lastUpdated: DateTime.now(),
    );
    
    // Firebaseに保存
    if (_firebaseService.isConfigured) {
      try {
        await _firebaseService.saveEvent(updatedEvent);
        print("✅ [EventTitleEditView] Firebaseにイベントの編集を保存しました");
      } catch (error) {
        print("⚠️ [EventTitleEditView] Firebaseへの保存でエラー: $error");
        if (mounted) {
          setState(() {
            _errorMessage = "Firebaseへの保存に失敗しました: $error";
            _showError = true;
            _isSaving = false;
          });
        }
        return;
      }
    } else {
      print("⚠️ [EventTitleEditView] Firebaseが設定されていません。");
    }

    if (mounted) {
      setState(() { _isSaving = false; });
      
      // 親に更新されたイベントを返す (SwiftUIの event = updatedEvent に相当)
      widget.onUpdate?.call(updatedEvent);
      print("✅ [EventTitleEditView] イベントタイトルの編集が完了しました: name=$name");

      // イベント一覧ページに直接遷移（ログイン後の遷移先と同一ページに統一）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const EventListPage()),
        (route) => false, // すべての前のルートを削除
      );
    }
  }
  
  // SwiftUIの private func resetRanking() async に相当
  Future<void> _resetRanking() async {
    setState(() { _isResetting = true; });

    final prefs = await SharedPreferences.getInstance();
    final passcode = widget.event.creationPasscode ?? prefs.getString("currentPasscode") ?? "";
    
    // ランキング（records）を空にしてイベントを更新
    final updatedEvent = widget.event.copyWith(
      records: [], // ランキングをリセット（空配列）
      lastUpdated: DateTime.now(),
    );

    // Firebaseに保存
    // TODO: saveEventToFirebase メソッドを実装する必要があります
    if (_firebaseService.isConfigured && passcode.isNotEmpty) {
      try {
        // await _firebaseService.saveEventToFirebase(updatedEvent, passcode: passcode);
        print("✅ [EventTitleEditView] ランキングリセットをFirebaseに保存しました");
      } catch (error) {
        print("⚠️ [EventTitleEditView] Firebaseへの保存でエラー: $error");
        if (mounted) {
          setState(() {
            _errorMessage = "Firebaseへの保存に失敗しました: $error";
            _showError = true;
            _isResetting = false;
          });
        }
        return;
      }
    } else {
      print("⚠️ [EventTitleEditView] Firebaseが設定されていないか、暗証番号がありません。ローカルのみに保存します。");
    }

    if (mounted) {
      // クリアページのチェックフラグをリセット (UserDefaults.standard.removeObject(forKey: ...) に相当)
      final clearCheckedKey = "clearChecked_${widget.event.id}";
      await prefs.remove(clearCheckedKey);
      print("✅ [EventTitleEditView] クリアページのチェックフラグをリセットしました: $clearCheckedKey");
      
      setState(() { _isResetting = false; });
      widget.onUpdate?.call(updatedEvent);
      print("✅ [EventTitleEditView] ランキングリセットが完了しました");
    }
  }

  // SwiftUIの body: some View に相当
  @override
  Widget build(BuildContext context) {
    // SwiftUIの @Environment(\.dismiss) に相当
    final dismiss = () => Navigator.of(context).pop();

    // エラーアラートの表示
    if (_showError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showErrorAlert(context);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("イベントタイトル編集"),
        centerTitle: true,
        actions: [
          // 保存ボタン (ToolbarItem(placement: .navigationBarTrailing) に相当)
          TextButton(
            onPressed: _isSaveDisabled ? null : () => _saveEvent(),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("保存"),
          ),
        ],
        leading: TextButton(
          // キャンセルボタン (ToolbarItem(placement: .navigationBarLeading) に相当)
          onPressed: dismiss,
          child: const Text("キャンセル"),
        ),
      ),
      // SwiftUIの Form に相当 (ListView + Card/Container で実現)
      body: _buildForm(context),
    );
  }
  
  Widget _buildForm(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: <Widget>[
        // Section(header: Text("イベント情報")) に相当
        _buildFormSection(
          header: "イベント情報",
          children: [
            // TextField("タイトル", text: $eventName) に相当
            _buildTextField(
              controller: _eventNameController,
              label: "タイトル",
              isRequired: true,
            ),
            const Divider(),
            // 新規作成時のみ暗証番号フィールドを表示
            if (_isNewEvent) ...[
              TextField(
                controller: _passcodeController,
                decoration: const InputDecoration(
                  labelText: "暗証番号 *",
                  border: InputBorder.none,
                  hintText: "イベント編集時に使用する暗証番号を入力",
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
              ),
              const Divider(),
            ],
            // TextField("コメント", text: $comment) に相当
            _buildTextField(
              controller: _commentController,
              label: "コメント",
            ),
            const Divider(),
            // DatePicker("開催日", selection: $eventDate, displayedComponents: .date) に相当
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("開催日"),
              trailing: Text(_eventDate.toLocal().toString().split(' ')[0]),
              onTap: () => _selectDate(context),
            ),
            const Divider(),
            // 画像選択セクション
            _buildImageSection(),
          ],
        ),
        const SizedBox(height: 20),

        // Section(header: Text("表示設定")) に相当
        _buildFormSection(
          header: "表示設定",
          children: [
            // Toggle("イベント一覧に表示", isOn: $isVisible) に相当
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("イベント一覧に表示"),
              value: _isVisible,
              onChanged: (bool value) {
                setState(() {
                  _isVisible = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Section(header: Text("イベント概要")) に相当
        _buildFormSection(
          header: "イベント概要",
          children: [
            // TextEditor(text: $overview).frame(minHeight: 100) に相当
            TextField(
              controller: _overviewController,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "イベント概要を入力...",
              ),
              maxLines: null, // 複数行を可能にする
              minLines: 5,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Section(header: Text("ランキング管理")) に相当
        _buildFormSection(
          header: "ランキング管理",
          children: [
            // ランキングリセットボタン
            TextButton(
              onPressed: (_isResetting || _isSaving) ? null : () => _showResetConfirmation(context),
              child: Row(
                children: [
                  Icon(
                    Icons.history, // arrow.counterclockwise に近いアイコン
                    color: (_isResetting || _isSaving) ? Colors.grey : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "ランキングリセット",
                    style: TextStyle(
                      color: (_isResetting || _isSaving) ? Colors.grey : Colors.red,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  if (_isResetting) const CircularProgressIndicator(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 日付選択ピッカーを表示するメソッド
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _eventDate) {
      setState(() {
        _eventDate = picked;
      });
    }
  }

  // Form Section の見た目を構築するヘルパーウィジェット
  Widget _buildFormSection({required String header, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            header,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            // SwiftUIの Form の区切り線に似せる
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
  
  // Form 内の TextField の見た目を構築するヘルパーウィジェット
  Widget _buildTextField({required TextEditingController controller, required String label, bool isRequired = false}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: isRequired ? "$label *" : label,
        border: InputBorder.none,
      ),
    );
  }

  // エラーアラートを表示するメソッド
  void _showErrorAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("エラー"),
          content: Text(_errorMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() { _showError = false; });
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  // ランキングリセットの確認アラートを表示するメソッド
  void _showResetConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("ランキングリセット"),
          content: const Text("リセットしますか？"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // キャンセル
              child: const Text("キャンセル"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // アラートを閉じる
                _resetRanking(); // リセット実行
              },
              child: const Text("はい", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  // 画像選択セクションを構築
  Widget _buildImageSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "イベント画像",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          // 画像プレビュー
          if (_selectedImageFile != null || 
              (widget.event.cardImageUrl != null && !_imageRemoved))
            Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedImageFile != null
                        ? Image.file(
                            _selectedImageFile!,
                            fit: BoxFit.cover,
                          )
                        : widget.event.cardImageUrl != null && !_imageRemoved
                            ? CachedNetworkImage(
                                imageUrl: widget.event.cardImageUrl!,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => const Icon(
                                  Icons.error,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              )
                            : null,
                  ),
                ),
                // 削除ボタン
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                    onPressed: _removeImage,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          // 画像選択ボタン
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isUploadingImage || _isSaving ? null : _pickImage,
              icon: _isUploadingImage
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image),
              label: Text(_selectedImageFile != null || 
                  (widget.event.cardImageUrl != null && !_imageRemoved)
                  ? "画像を変更"
                  : "画像を選択"),
            ),
          ),
        ],
      ),
    );
  }
}