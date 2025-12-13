// duration_editor_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ----------------------------------------------------
// DurationEditorView (制限時間設定画面)
// ----------------------------------------------------

class DurationEditorView extends StatefulWidget {
  // SwiftUIの @Binding var duration: Int に相当
  final int initialDuration;

  // SwiftUIの @Binding var isPresented: Bool に相当（モーダルを閉じるためのメソッド）
  // 実際には Navigator.pop() を使って値を返し、親で閉じる処理を行う
  
  const DurationEditorView({
    super.key,
    required this.initialDuration,
  });

  @override
  State<DurationEditorView> createState() => _DurationEditorViewState();
  
  // モーダルとして表示するためのヘルパー関数
  static Future<int?> showModal(BuildContext context, int currentDuration) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true, // 全画面モーダルのように見せるために設定
      builder: (context) {
        // Safe Area の下に回り込むのを防ぐ
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: DurationEditorView(initialDuration: currentDuration),
        );
      },
    );
  }
}

class _DurationEditorViewState extends State<DurationEditorView> {
  // SwiftUIの @State private var durationString: String = "" に相当
  final TextEditingController _durationController = TextEditingController();
  
  // 現在の制限時間（親から受け取った初期値）
  late int _currentDuration; 
  
  // 入力値が有効かどうかをチェックする Getter
  bool get _isInputValid {
    final text = _durationController.text;
    if (text.isEmpty) return false;
    final value = int.tryParse(text);
    return value != null && value > 0;
  }
  
  // 入力された新しい制限時間
  int? get _newDuration {
    return int.tryParse(_durationController.text);
  }

  @override
  void initState() {
    super.initState();
    _currentDuration = widget.initialDuration;
    // SwiftUIの .onAppear { durationString = String(duration) } に相当
    _durationController.text = _currentDuration.toString();
    _durationController.addListener(_updateState);
  }
  
  @override
  void dispose() {
    _durationController.removeListener(_updateState);
    _durationController.dispose();
    super.dispose();
  }
  
  // TextFieldの変更を検知してsetStateを呼び出すためのメソッド
  void _updateState() {
    setState(() {});
  }

  // SwiftUIの private func saveDuration() に相当
  void _saveDuration() {
    if (_isInputValid) {
      final newDuration = int.parse(_durationController.text);
      // 親ウィジェットに新しい値を返して画面を閉じる
      Navigator.of(context).pop(newDuration);
    }
  }
  
  // SwiftUIの "キャンセル" ボタンのアクションに相当
  void _cancel() {
    // 値を返さずに画面を閉じる
    Navigator.of(context).pop(); 
  }

  @override
  Widget build(BuildContext context) {
    // SwiftUIの NavigationStack に相当 (ScaffoldとAppBarで実現)
    return Scaffold(
      appBar: AppBar(
        // SwiftUIの .navigationTitle("制限時間設定") と .navigationBarTitleDisplayMode(.inline) に相当
        title: const Text("制限時間設定"),
        centerTitle: true,
        // ToolbarItem(placement: .navigationBarLeading) に相当
        leading: TextButton(
          onPressed: _cancel,
          child: const Text("キャンセル"),
        ),
        // ToolbarItem(placement: .navigationBarTrailing) に相当
        actions: [
          TextButton(
            onPressed: _isInputValid ? _saveDuration : null, // .disabled(...) に相当
            child: const Text("保存"),
          ),
        ],
      ),
      // SwiftUIの Form に相当 (ListView + Padding で実現)
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section(header: Text("制限時間"), footer: Text(...)) に相当
              _buildSection(
                context,
                header: "制限時間",
                footer: "イベント全体の制限時間を分単位で設定します",
                children: [
                  _buildDurationInput(),
                ],
              ),
              const SizedBox(height: 30),
              
              // Section { VStack(...) } に相当
              _buildSection(
                context,
                children: [
                  _buildCurrentSettings(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDurationInput() {
    // SwiftUIの HStack と TextField(.numberPad) に相当
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _durationController,
            decoration: const InputDecoration(
              labelText: "分数",
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly // 数字のみ入力可能にする
            ],
            // 変更は _updateState リスナーで処理される
          ),
        ),
        const SizedBox(width: 8),
        // Text("分").foregroundColor(.secondary) に相当
        const Text(
          "分",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }
  
  Widget _buildCurrentSettings() {
    // SwiftUIの VStack(alignment: .leading, spacing: 8) に相当
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text("現在の設定: \(duration)分") に相当
        Text(
          "現在の設定: $_currentDuration分",
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 8),
        
        // 新しい設定の表示ロジック
        if (_isInputValid) 
          Text(
            "新しい設定: ${_newDuration!}分",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue),
          ),
      ],
    );
  }

  // SwiftUIの Form Section に近い見た目を実現するためのヘルパーメソッド
  Widget _buildSection(BuildContext context, {String? header, String? footer, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) 
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              header.toUpperCase(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
        if (footer != null) 
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              footer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
      ],
    );
  }
}

// ----------------------------------------------------
// Preview / 呼び出し側のサンプル
// ----------------------------------------------------
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duration Editor Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const DemoParentView(),
    );
  }
}

class DemoParentView extends StatefulWidget {
  const DemoParentView({super.key});

  @override
  State<DemoParentView> createState() => _DemoParentViewState();
}

class _DemoParentViewState extends State<DemoParentView> {
  int _eventDuration = 60; // 初期値

  void _openDurationEditor() async {
    // モーダルを表示し、結果を待つ
    final resultDuration = await DurationEditorView.showModal(
      context, 
      _eventDuration
    );

    // キャンセルされなかった場合（nullでない場合）、値を更新
    if (resultDuration != null) {
      setState(() {
        _eventDuration = resultDuration;
      });
      print("⏱️ 制限時間が $resultDuration分 に更新されました。");
    } else {
      print("キャンセルされました。");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("設定デモ画面")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "現在の制限時間: $_eventDuration分",
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _openDurationEditor,
              child: const Text("制限時間設定を開く"),
            ),
          ],
        ),
      ),
    );
  }
}