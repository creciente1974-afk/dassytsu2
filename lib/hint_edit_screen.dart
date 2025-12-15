import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'lib/models/hint.dart'; // Hint モデルをインポート

// SwiftのUUID生成に対応するため、'uuid' パッケージが必要です。
// pubspec.yaml に uuid: ^latest_version を追加してください。
const Uuid _uuid = Uuid();

class HintEditScreen extends StatefulWidget {
  // 既存のヒント (編集の場合)
  final Hint? initialHint;
  
  // ヒントが保存されたときに親に値を返すためのコールバック関数
  // bool isNew: trueなら新規作成、falseなら更新
  final void Function(Hint updatedHint, bool isNew)? onSave;

  const HintEditScreen({
    super.key,
    this.initialHint,
    this.onSave,
  });

  @override
  State<HintEditScreen> createState() => _HintEditScreenState();
}

class _HintEditScreenState extends State<HintEditScreen> {
  // @State private var content: String = "" に相当
  late TextEditingController _contentController;
  // @State private var timeOffset: String = "" に相当
  late TextEditingController _timeOffsetController;
  
  final _formKey = GlobalKey<FormState>();

  // 画面タイトルを決定
  String get _screenTitle => widget.initialHint != null ? 'ヒント編集' : '新規ヒント';
  
  // 保存ボタンの有効/無効を判定
  bool get _isSaveEnabled => 
      _contentController.text.isNotEmpty && 
      _timeOffsetController.text.isNotEmpty &&
      int.tryParse(_timeOffsetController.text) != null;

  @override
  void initState() {
    super.initState();
    // loadHintData() に相当する初期化処理
    _contentController = TextEditingController(
      text: widget.initialHint?.content ?? '',
    );
    // timeOffsetは秒単位で保存されているが、UIでは分単位で表示・入力する
    final minutes = widget.initialHint != null 
        ? (widget.initialHint!.timeOffset / 60).round()
        : null;
    _timeOffsetController = TextEditingController(
      text: minutes?.toString() ?? '',
    );
    
    // TextFieldの値が変更されたらsetStateを呼び出し、保存ボタンの有効/無効を更新
    _contentController.addListener(_updateSaveButtonState);
    _timeOffsetController.addListener(_updateSaveButtonState);
  }

  void _updateSaveButtonState() {
    // setStateを呼び出して、_isSaveEnabledの再評価とAppBarの再描画をトリガー
    setState(() {}); 
  }

  @override
  void dispose() {
    _contentController.removeListener(_updateSaveButtonState);
    _timeOffsetController.removeListener(_updateSaveButtonState);
    _contentController.dispose();
    _timeOffsetController.dispose();
    super.dispose();
  }

  // private func saveHint() に相当
  void _saveHint() {
    if (!_formKey.currentState!.validate()) {
      return; // バリデーションに失敗したら何もしない
    }
    
    final int? minutesInt = int.tryParse(_timeOffsetController.text);
    if (minutesInt == null || minutesInt < 0) {
      // timeOffsetのバリデーションはTextFieldのinputFormattersとvalidateでカバーされているはずだが念のため
      return;
    }

    final bool isNew = widget.initialHint == null;
    
    // 分を秒に変換（timeOffsetは秒単位で保存される）
    final int timeOffsetInSeconds = minutesInt * 60;
    
    // Hint(id: content: timeOffset:) の作成
    final Hint updatedHint = Hint(
      // 既存IDがあればそれを使用、なければ新規UUIDを生成
      id: widget.initialHint?.id ?? _uuid.v4(),
      content: _contentController.text,
      timeOffset: timeOffsetInSeconds,
    );
    
    // onSave?() の実行
    widget.onSave?.call(updatedHint, isNew);
    
    // isPresented.wrappedValue = false に相当
    // 画面を閉じる
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // NavigationStack { ... } に相当
    return Scaffold(
      appBar: AppBar(
        title: Text(_screenTitle), // .navigationTitle() に相当
        leading: TextButton(
          onPressed: () {
            // キャンセルボタン
            Navigator.of(context).pop();
          },
          child: const Text('キャンセル'), // ToolbarItem(placement: .navigationBarLeading) に相当
        ),
        actions: [
          TextButton(
            onPressed: _isSaveEnabled ? _saveHint : null, // 保存ボタン
            child: const Text('保存'), // ToolbarItem(placement: .navigationBarTrailing) に相当
          ),
        ],
      ),
      // Form { ... } に相当
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Section(header: Text("ヒント内容")) に相当
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ヒント内容",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'ヒントの内容を入力してください',
                  ),
                  maxLines: 5, // .frame(minHeight: 100) に相当
                  minLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'ヒント内容は必須です。';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),

            // Section(header: Text("表示タイミング"), footer: Text("...")) に相当
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "表示タイミング",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _timeOffsetController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: '分数',
                        ),
                        keyboardType: TextInputType.number, // .keyboardType(.numberPad) に相当
                        // 数値入力のみに制限
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '表示タイミングは必須です。';
                          }
                          if (int.tryParse(value) == null || int.parse(value) < 0) {
                            return '有効な分数を入力してください。';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "分後",
                      style: TextStyle(color: Colors.grey),
                    ), // .foregroundColor(.secondary) に相当
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "問題開始から何分後にこのヒントを表示するかを設定します",
                  style: TextStyle(fontSize: 12, color: Colors.grey), // footer に相当
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// MARK: - プレビュー/使用例

// プレビューアブル機能がないため、標準的なメイン関数と画面遷移の例を提供します。

/*
// 使用例：ボタンが押されたときに画面を表示する例
class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  List<Hint> _hints = [
    Hint(id: _uuid.v4(), content: "初期ヒント1", timeOffset: 5),
    Hint(id: _uuid.v4(), content: "初期ヒント2", timeOffset: 10),
  ];

  void _openHintEditScreen({Hint? hintToEdit}) async {
    // 画面遷移
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => HintEditScreen(
          initialHint: hintToEdit,
          onSave: (updatedHint, isNew) {
            setState(() {
              if (isNew) {
                // 新規追加
                _hints.add(updatedHint);
              } else {
                // 更新 (IDで検索して置き換え)
                final index = _hints.indexWhere((h) => h.id == updatedHint.id);
                if (index != -1) {
                  _hints[index] = updatedHint;
                }
              }
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("ヒント一覧")),
      body: ListView.builder(
        itemCount: _hints.length,
        itemBuilder: (context, index) {
          final hint = _hints[index];
          return ListTile(
            title: Text(hint.content),
            subtitle: Text("${hint.timeOffset} 分後に表示"),
            onTap: () => _openHintEditScreen(hintToEdit: hint), // 編集
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openHintEditScreen(), // 新規作成
        child: const Icon(Icons.add),
      ),
    );
  }
}
*/