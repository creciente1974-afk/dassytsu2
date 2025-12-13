// event_title_edit_view.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// --- 仮定されるデータモデルとサービス ---
// 実際のプロジェクトに合わせて調整してください。

class Event {
  final String id; // UUID
  String name;
  final List<dynamic> problems; // 問題リスト
  final int duration; // 制限時間
  List<dynamic> records; // ランキング記録
  final String? target_object_text;
  final String? target_object_image_url;
  final String? card_image_url;
  final String? creation_passcode;
  DateTime? eventDate;
  bool isVisible;
  String? comment;
  String? overview;
  final String? qrCodeData;
  DateTime? lastUpdated;

  Event({
    required this.id,
    required this.name,
    required this.problems,
    required this.duration,
    required this.records,
    this.target_object_text,
    this.target_object_image_url,
    this.card_image_url,
    this.creation_passcode,
    this.eventDate,
    required this.isVisible,
    this.comment,
    this.overview,
    this.qrCodeData,
    this.lastUpdated,
  });
  
  // イベントのコピーを作成し、新しい値を適用するためのファクトリコンストラクタ
  Event.update({
    required Event oldEvent,
    String? name,
    DateTime? eventDate,
    bool? isVisible,
    String? comment,
    String? overview,
    List<dynamic>? records,
  }) : this(
    id: oldEvent.id,
    name: name ?? oldEvent.name,
    problems: oldEvent.problems,
    duration: oldEvent.duration,
    records: records ?? oldEvent.records,
    target_object_text: oldEvent.target_object_text,
    target_object_image_url: oldEvent.target_object_image_url,
    card_image_url: oldEvent.card_image_url,
    creation_passcode: oldEvent.creation_passcode,
    eventDate: eventDate ?? oldEvent.eventDate,
    isVisible: isVisible ?? oldEvent.isVisible,
    comment: comment,
    overview: overview,
    qrCodeData: oldEvent.qrCodeData,
    lastUpdated: DateTime.now(), // 更新時は常に日時を更新
  );
}

// FirebaseService の仮定
class FirebaseService {
  static final FirebaseService shared = FirebaseService._internal();
  FirebaseService._internal();
  
  bool get isConfigured => true; // Firebase設定済みと仮定

  Future<void> saveEventToFirebase(Event event, {required String passcode}) async {
    // 実際はFirestoreに保存するロジックを実装
    await Future.delayed(const Duration(milliseconds: 500));
    print("FirestoreにイベントID: ${event.id} を保存しました。");
  }
}

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
  late DateTime _eventDate;
  late bool _isVisible;
  
  bool _isSaving = false;
  bool _isResetting = false;
  
  // エラー/アラートの状態
  bool _showError = false;
  String _errorMessage = "";
  
  final FirebaseService _firebaseService = FirebaseService.shared;

  @override
  void initState() {
    super.initState();
    // SwiftUIの init() 内での初期値設定に相当
    _eventNameController = TextEditingController(text: widget.event.name);
    _commentController = TextEditingController(text: widget.event.comment);
    _overviewController = TextEditingController(text: widget.event.overview);
    _eventDate = widget.event.eventDate ?? DateTime.now();
    _isVisible = widget.event.isVisible;
  }
  
  @override
  void dispose() {
    _eventNameController.dispose();
    _commentController.dispose();
    _overviewController.dispose();
    super.dispose();
  }

  // 保存ボタンの有効/無効を判定するGetter
  bool get _isSaveDisabled {
    return _eventNameController.text.trim().isEmpty || _isSaving || _isResetting;
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

    // 暗証番号を取得 (UserDefaults.standard.string(forKey: "currentPasscode") に相当)
    final prefs = await SharedPreferences.getInstance();
    final passcode = widget.event.creation_passcode ?? prefs.getString("currentPasscode") ?? "";

    // イベントオブジェクトを更新
    final updatedEvent = Event.update(
      oldEvent: widget.event,
      name: name,
      eventDate: _eventDate,
      isVisible: _isVisible,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      overview: _overviewController.text.trim().isEmpty ? null : _overviewController.text.trim(),
    );
    
    // Firebaseに保存
    if (_firebaseService.isConfigured && passcode.isNotEmpty) {
      try {
        await _firebaseService.saveEventToFirebase(updatedEvent, passcode: passcode);
        print("✅ [EventTitleEditView] Firebaseにイベントの編集を保存しました");
      } catch (error) {
        print("⚠️ [EventTitleEditView] Firebaseへの保存でエラー: $error");
        if (mounted) {
          setState(() {
            _errorMessage = "Firebaseへの保存に失敗しました: $error";
            _showError = true;
          });
        }
      }
    } else {
      print("⚠️ [EventTitleEditView] Firebaseが設定されていないか、暗証番号がありません。ローカルのみに保存します。");
    }

    if (mounted) {
      setState(() { _isSaving = false; });
      
      // 親に更新されたイベントを返す (SwiftUIの event = updatedEvent に相当)
      widget.onUpdate?.call(updatedEvent);
      print("✅ [EventTitleEditView] イベントタイトルの編集が完了しました: name=$name");

      // 画面を閉じる (dismiss() に相当)
      Navigator.of(context).pop();
    }
  }
  
  // SwiftUIの private func resetRanking() async に相当
  Future<void> _resetRanking() async {
    setState(() { _isResetting = true; });

    final prefs = await SharedPreferences.getInstance();
    final passcode = widget.event.creation_passcode ?? prefs.getString("currentPasscode") ?? "";
    
    // ランキング（records）を空にしてイベントを更新
    final updatedEvent = Event.update(
      oldEvent: widget.event,
      records: [], // ランキングをリセット（空配列）
    );

    // Firebaseに保存
    if (_firebaseService.isConfigured && passcode.isNotEmpty) {
      try {
        await _firebaseService.saveEventToFirebase(updatedEvent, passcode: passcode);
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
}