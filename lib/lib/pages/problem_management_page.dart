// lib/pages/problem_management_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 状態管理のため（今回は使わないが、将来のEvent変更通知に便利）
import 'dart:io';

// 必要なモデルとサービスのインポート
import '../models/problem.dart';
import '../models/event.dart'; // Eventモデルの構造が必要
import '../services/firebase_service.dart';
import '../utils/qr_code_generator.dart'; // QRコード生成ユーティリティ（別途作成が必要）

// ダミーのエラーハンドリングクラス（FirebaseServiceErrorと連携）
class FirebaseServiceError implements Exception {
  final String message;
  final String? code;
  FirebaseServiceError(this.message, {this.code});
  @override
  String toString() => 'FirebaseServiceError: $message ${code != null ? '($code)' : ''}';
  static fromFirebaseDatabaseError(dynamic e) => FirebaseServiceError(e.toString());
}

// --------------------------------------------------------------------------
// 1. ProblemRow (問題一覧の行)
// --------------------------------------------------------------------------

class ProblemRow extends StatelessWidget {
  final Problem problem;
  final VoidCallback onEdit;

  const ProblemRow({
    super.key,
    required this.problem,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 問題文
          if (problem.text != null && problem.text!.isNotEmpty)
            Text(
              problem.text!,
              style: const TextStyle(fontSize: 16.0),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          else
            const Text(
              '（問題文なし）',
              style: TextStyle(fontSize: 16.0, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          
          const SizedBox(height: 8),

          // 情報と編集ボタン
          Row(
            children: [
              // メディア情報
              if (problem.mediaURL.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(right: 8.0),
                  child: Chip(
                    label: Text("メディアあり", style: TextStyle(fontSize: 10)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ),
                ),
              
              // ヒント情報
              if (problem.hints.isNotEmpty)
                Chip(
                  label: Text("ヒント: ${problem.hints.length}", style: const TextStyle(fontSize: 10)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              
              const Spacer(),
              
              // 編集ボタン
              TextButton(
                onPressed: onEdit,
                child: const Text("編集"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// 2. ProblemManagementPage (メインビュー)
// --------------------------------------------------------------------------

class ProblemManagementPage extends StatefulWidget {
  // Swiftの @Binding var event: Event に相当
  final Event event;
  final ValueChanged<Event> onEventUpdated; // イベントが更新されたことを親に通知
  final VoidCallback onDelete; // イベントが削除されたことを親に通知

  const ProblemManagementPage({
    super.key,
    required this.event,
    required this.onEventUpdated,
    required this.onDelete,
  });

  @override
  State<ProblemManagementPage> createState() => _ProblemManagementPageState();
}

class _ProblemManagementPageState extends State<ProblemManagementPage> {
  // Swiftの @State 変数に対応
  late Event _currentEvent; // 編集可能な状態としてローカルに保持
  Problem? _showProblemEditor; // 編集対象の問題
  bool _isAddingNewProblem = false;
  bool _showDurationEditor = false;
  bool _showTitleEditor = false;
  bool _isSaving = false;
  bool _showError = false;
  String _errorMessage = "";
  bool _showQRCodeGenerator = false;
  // QRコード生成後のイメージはStateには保持せず、生成ロジック内で処理するか、
  // QRコード表示用の画面に渡すデータとして用意します。

  final FirebaseService _firebaseService = FirebaseService(); // Singleton インスタンスを取得

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event; // 親から渡された初期値を設定
  }

  // MARK: - データの操作ロジック

  /// イベント全体をFirebaseに保存
  Future<void> _saveEventToFirebase() async {
    // SwiftコードのsaveEventToFirebase()を移植
    
    // 暗証番号の取得（SwiftのUserDefaults.standard.string(forKey: "currentPasscode")の代替）
    // NOTE: ここでは簡略化のため、event.creationPasscodeを使用しますが、
    // 実際には shared_preferences などを使って永続化された値を取得するロジックが必要です。
    final passcode = _currentEvent.creationPasscode ?? 'DUMMY_PASSCODE'; // 仮の代替

    if (passcode == null) {
      _showErrorAlert("暗証番号が見つかりません。Firebaseに保存をスキップします。");
      widget.onEventUpdated(_currentEvent); // ローカル更新を親に通知
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // FirebaseServiceには saveEvent(Event event) があると仮定
      await _firebaseService.saveEvent(_currentEvent);
      debugPrint("✅ [ProblemManagementPage] Firebaseにイベントを保存しました: ${_currentEvent.id}");

      if (!mounted) return;
      
      // 保存成功後、親ウィジェットに更新されたEventを通知
      widget.onEventUpdated(_currentEvent); 

    } catch (e) {
      debugPrint("❌ [ProblemManagementPage] Firebase保存エラー: $e");
      if (!mounted) return;
      _showErrorAlert("Firebaseへの保存に失敗しました: ${e.toString()}");
      widget.onEventUpdated(_currentEvent); // エラーが発生してもローカル更新を親に通知
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// 問題の追加
  void _addProblem(Problem newProblem) {
    // EventモデルのcopyWith/updateが理想だが、ここでは直接リストを操作
    setState(() {
      _currentEvent.problems.add(newProblem);
    });
  }

  /// 問題の削除
  void _deleteProblems(int index) {
    setState(() {
      _currentEvent.problems.removeAt(index);
    });
    // 削除後、Firebaseに保存
    _saveEventToFirebase();
  }
  
  /// 問題の更新
  void _updateProblem(Problem updatedProblem) {
    final index = _currentEvent.problems.indexWhere((p) => p.id == updatedProblem.id);
    if (index != -1) {
      setState(() {
        _currentEvent.problems[index] = updatedProblem;
      });
    }
  }

  /// イベント制限時間の更新
  void _updateEventDuration(int newDuration) {
    setState(() {
      // Eventモデルのdurationフィールドを更新
      // NOTE: EventモデルにcopyWithがない場合、Eventを再構築する必要があります
      _currentEvent = _currentEvent.copyWith(duration: newDuration); 
    });
    // 時間変更後、Firebaseに保存
    _saveEventToFirebase();
  }
  
  /// イベントタイトルの更新（EventTitleEditView内で直接行うのが理想だが、ここでは保存後に親を更新）
  void _updateEventTitle(String newTitle) {
    setState(() {
      _currentEvent = _currentEvent.copyWith(title: newTitle);
    });
    // タイトル変更後、Firebaseに保存
    _saveEventToFirebase();
  }


  /// QRコードを作成してイベントに保存
  Future<void> _createQRCode() async {
    // 1. QRコードデータの生成
    final qrData = QRCodeGenerator.generateQRCodeData(
      // Swiftの event.name, event.eventDate に対応するフィールドを使用
      eventName: _currentEvent.title, // Event.name -> Event.title に変更を仮定
      eventId: _currentEvent.id,
      // NOTE: Eventモデルに eventDate がないため、ここでは現在時刻を仮定
      eventDate: DateTime.now(), 
    );
    
    // 2. EventモデルにQRコードデータを保存（ローカル更新）
    setState(() {
      _currentEvent = _currentEvent.copyWith(qrCodeData: qrData);
    });

    // 3. Firebaseに保存
    await _saveEventToFirebase();
    
    // 4. QRコード表示画面を表示
    if (mounted) {
      setState(() {
        _showQRCodeGenerator = true;
      });
    }
  }

  // MARK: - UIヘルパー

  void _showErrorAlert(String message) {
    setState(() {
      _errorMessage = message;
      _showError = true;
    });
  }

  // MARK: - ビルドメソッド

  @override
  Widget build(BuildContext context) {
    // 画面全体をScaffoldで囲む
    return Scaffold(
      appBar: AppBar(
        title: const Text("問題管理"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _isAddingNewProblem = true;
              });
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // イベント情報と設定ボタン
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentEvent.title, // Swiftの event.name に相当
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // 制限時間表示
                    Text(
                      "制限時間: ${_currentEvent.duration}分",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                    ),
                    const Spacer(),
                    
                    // タイトル編集ボタン
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text("タイトル編集", style: TextStyle(fontSize: 10)),
                      onPressed: () => setState(() => _showTitleEditor = true),
                    ),
                    const SizedBox(width: 8),

                    // 時間設定ボタン
                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 14),
                      label: const Text("時間設定", style: TextStyle(fontSize: 10)),
                      onPressed: () => setState(() => _showDurationEditor = true),
                    ),
                    const SizedBox(width: 8),
                    
                    // QRコード作成ボタン
                    OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code, size: 14),
                      label: const Text("QRコード作成", style: TextStyle(fontSize: 10)),
                      onPressed: _createQRCode,
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 問題一覧
          Expanded(
            child: ListView.builder(
              itemCount: _currentEvent.problems.length,
              itemBuilder: (context, index) {
                final problem = _currentEvent.problems[index];
                return Dismissible(
                  key: ValueKey(problem.id), // 一意のキーとしてProblem IDを使用
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteProblems(index); // 削除ロジックを呼び出す
                  },
                  child: ProblemRow(
                    problem: problem,
                    onEdit: () {
                      setState(() {
                        _showProblemEditor = problem;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      
      // 読み込み中インジケータ
      bottomNavigationBar: _isSaving
          ? const LinearProgressIndicator()
          : null,
      
      // MARK: - Modals / Sheets (Swiftの .sheet に相当)
      
      // 既存問題の編集シート
      // NOTE: ProblemEditPageを別途実装する必要があります
      // ここでは、Bottom Sheetで表示する例を示します
      // Swiftの .sheet(item: $showProblemEditor) に相当
      bottomSheet: _showProblemEditor != null
          ? SizedBox(
              height: MediaQuery.of(context).size.height * 0.9,
              child: ProblemEditPage(
                initialProblem: _showProblemEditor!,
                onSave: (updatedProblem) {
                  _updateProblem(updatedProblem); // ローカルのリストを更新
                  _showProblemEditor = null; // シートを閉じる
                  _saveEventToFirebase();
                  setState(() {});
                },
                onCancel: () {
                  _showProblemEditor = null;
                  setState(() {});
                },
                eventId: _currentEvent.id,
              ),
            )
          : null,
    );
  }
}

// --------------------------------------------------------------------------
// 3. ダミーウィジェット (ProblemEditPage, DurationEditorView, EventTitleEditView, QRCodeDisplayView)
// --------------------------------------------------------------------------

// NOTE: 実際のロジックに合わせて別途実装が必要です。

class ProblemEditPage extends StatelessWidget {
  final Problem initialProblem;
  final ValueChanged<Problem> onSave;
  final VoidCallback onCancel;
  final String eventId;

  const ProblemEditPage({
    super.key,
    required this.initialProblem,
    required this.onSave,
    required this.onCancel,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('問題編集 (ID: ${initialProblem.id})', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          TextField(
            controller: TextEditingController(text: initialProblem.text),
            decoration: const InputDecoration(labelText: '問題文'),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onCancel, child: const Text('キャンセル')),
              ElevatedButton(
                onPressed: () {
                  // TODO: 実際の編集ロジックを反映させる
                  onSave(initialProblem.copyWith(text: '編集後の問題文')); 
                  Navigator.pop(context); // シートを閉じる
                },
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
// DurationEditorView, EventTitleEditView, QRCodeDisplayView も同様にダミーが必要です。