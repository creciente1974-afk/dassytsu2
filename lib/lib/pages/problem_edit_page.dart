import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // カメラ・ギャラリー連携用
import 'dart:io'; // File型を使うためにインポート
import '../models/problem.dart'; // Problem, Hint モデル
import '../services/firebase_service.dart'; // Firebase Service

// 遷移先の画面（ここでは実装を省略し、仮のウィジェットを使用します）
class MediaUploadPage extends StatelessWidget {
  final ValueChanged<String> onMediaUrlSet;
  final String? eventId;
  final String? problemId;

  const MediaUploadPage({
    required this.onMediaUrlSet,
    this.eventId,
    this.problemId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("メディアアップロード")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // ダミーのメディアURLを返す
            onMediaUrlSet("https://example.com/media/sample.mp4");
            Navigator.pop(context);
          },
          child: const Text("ダミーURLをセットして閉じる"),
        ),
      ),
    );
  }
}

// ヒント編集画面（ここでは実装を省略し、仮のウィジェットを使用します）
class HintEditPage extends StatelessWidget {
  final Hint? hint;
  final ValueChanged<Hint> onSave;

  const HintEditPage({
    this.hint,
    required this.onSave,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(hint == null ? "新規ヒント" : "ヒント編集")),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            // ダミーのヒントを保存
            onSave(Hint(
              id: hint?.id ?? UniqueKey().toString(),
              content: hint?.content ?? "新しいヒント内容",
              timeOffset: hint?.timeOffset ?? 10,
            ));
            Navigator.pop(context);
          },
          child: const Text("ヒントを保存して閉じる"),
        ),
      ),
    );
  }
}


class ProblemEditPage extends StatefulWidget {
  // Swiftの problemBinding: Binding<Problem>? に相当
  final Problem? initialProblem; 
  // Swiftの onSave: ((Problem) -> Void)? に相当
  final ValueChanged<Problem>? onSave; 
  // Swiftの eventId: String? に相当
  final String? eventId; 

  const ProblemEditPage({
    this.initialProblem,
    this.onSave,
    this.eventId,
    super.key,
  });

  @override
  State<ProblemEditPage> createState() => _ProblemEditPageState();
}

class _ProblemEditPageState extends State<ProblemEditPage> {
  // MARK: - State Properties
  
  final _textController = TextEditingController();
  final _answerController = TextEditingController();
  final _mediaURLController = TextEditingController();
  final _checkTextController = TextEditingController();
  final _checkImageURLController = TextEditingController();

  List<Hint> _hints = [];
  bool _requiresCheck = true;
  bool _isUploadingCheckImage = false;
  
  String? _uploadError;

  final FirebaseService _firebaseService = FirebaseService.instance;

  // MARK: - Lifecycle (Swiftの init と onAppear の代替)
  
  @override
  void initState() {
    super.initState();
    _loadProblemData();
  }

  @override
  void dispose() {
    _textController.dispose();
    _answerController.dispose();
    _mediaURLController.dispose();
    _checkTextController.dispose();
    _checkImageURLController.dispose();
    super.dispose();
  }

  // MARK: - Data Loading
  
  void _loadProblemData() {
    final problem = widget.initialProblem;
    if (problem != null) {
      _textController.text = problem.text ?? "";
      _answerController.text = problem.answer;
      _mediaURLController.text = problem.mediaURL;
      _hints = List.from(problem.hints);
      _checkTextController.text = problem.checkText ?? "";
      _checkImageURLController.text = problem.checkImageURL ?? "";
      _requiresCheck = problem.requiresCheck;
    }
  }

  // MARK: - Action Methods

  /// 問題オブジェクトを作成し、保存コールバックを実行して画面を閉じる (Swiftの saveProblem)
  void _saveProblem() {
    if (_answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('答えは必須です。')),
      );
      return;
    }

    final problemId = widget.initialProblem?.id ?? UniqueKey().toString(); // FlutterではUUIDの代わりにUniqueKey().toString()を使用
    
    final updatedProblem = Problem(
      id: problemId,
      text: _textController.text.trim().isEmpty ? null : _textController.text.trim(),
      mediaURL: _mediaURLController.text,
      answer: _answerController.text.trim(),
      hints: _hints,
      checkText: _checkTextController.text.trim().isEmpty ? null : _checkTextController.text.trim(),
      checkImageURL: _checkImageURLController.text.trim().isEmpty ? null : _checkImageURLController.text.trim(),
      requiresCheck: _requiresCheck,
    );

    widget.onSave?.call(updatedProblem);

    // 画面を閉じる (Swiftの isPresented.wrappedValue = false)
    Navigator.of(context).pop();
  }

  /// ヒントを追加する (Swiftの addHint)
  void _addHint(Hint newHint) {
    setState(() {
      _hints.add(newHint);
    });
  }

  /// ヒントを削除する (Swiftの deleteHints)
  void _deleteHint(int index) {
    setState(() {
      _hints.removeAt(index);
    });
  }

  /// ヒント編集画面へ遷移 (sheet)
  void _openHintEditPage({Hint? hint}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => HintEditPage(
        hint: hint,
        onSave: (updatedHint) {
          if (hint == null) {
            // 新規追加
            _addHint(updatedHint);
          } else {
            // 既存の編集
            setState(() {
              final index = _hints.indexWhere((h) => h.id == updatedHint.id);
              if (index != -1) {
                _hints[index] = updatedHint;
              }
            });
          }
        },
      ),
    );
  }

  /// チェック画像をアップロードする (Swiftの uploadCheckImage)
  Future<void> _uploadCheckImage(File imageFile) async {
    final eventId = widget.eventId;
    if (eventId == null) {
      _showErrorAlert("イベントIDが設定されていません");
      return;
    }
    final problemId = widget.initialProblem?.id ?? UniqueKey().toString();

    setState(() {
      _isUploadingCheckImage = true;
      _uploadError = null;
    });

    try {
      final imageURL = await _firebaseService.uploadReferenceImage(
        imageFile,
        eventId: eventId,
        problemId: problemId,
      );

      setState(() {
        _checkImageURLController.text = imageURL;
        _isUploadingCheckImage = false;
      });
      // CheckImageUploadViewを閉じる（呼び出し元のsetStateで閉じられる）
    } catch (error) {
      setState(() {
        _isUploadingCheckImage = false;
        _showErrorAlert("画像のアップロードに失敗しました: ${error.toString()}");
      });
    }
  }

  /// エラーダイアログを表示
  void _showErrorAlert(String message) {
    setState(() {
      _uploadError = message;
    });
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("エラー"),
        content: Text(_uploadError ?? "不明なエラーが発生しました"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    ).then((_) {
      setState(() {
        _uploadError = null; // ダイアログが閉じたらエラー状態をリセット
      });
    });
  }

  // MARK: - UI Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialProblem != null ? "問題編集" : "新規問題"),
        centerTitle: true,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("キャンセル"),
        ),
        actions: [
          TextButton(
            onPressed: _answerController.text.trim().isEmpty ? null : _saveProblem,
            child: const Text("保存"),
          ),
        ],
      ),
      // Swiftの Form に相当する ListView/SingleChildScrollView
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // MARK: 問題文
          _buildSectionHeader("問題文"),
          SizedBox(
            height: 100, // minHeight: 100 に相当
            child: TextField(
              controller: _textController,
              keyboardType: TextInputType.multiline,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // MARK: 答え
          _buildSectionHeader("答え"),
          TextField(
            controller: _answerController,
            decoration: const InputDecoration(
              labelText: "答えを入力",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),

          // MARK: メディア
          _buildSectionHeader("メディア"),
          ListTile(
            title: const Text("写真または動画をアップロード"),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // MediaUploadViewへの遷移
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => MediaUploadPage(
                    onMediaUrlSet: (url) {
                      setState(() {
                        _mediaURLController.text = url;
                      });
                    },
                    eventId: widget.eventId,
                    problemId: widget.initialProblem?.id,
                  ),
                ),
              );
            },
          ),
          if (_mediaURLController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("プレビュー", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  // 実際には動画/画像をロードするウィジェット (MediaViewの代替)
                  Container(
                    height: 200,
                    color: Colors.grey[200],
                    alignment: Alignment.center,
                    child: const Text("メディアプレビュー (Image/Video Player)", style: TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "メディアが設定されていません",
                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 24),

          // MARK: ヒント
          _buildHintSection(),
          const SizedBox(height: 24),

          // MARK: チェックページ設定
          _buildSectionHeader("チェックページ設定"),
          SwitchListTile(
            title: const Text("認証チェックを有効にする"),
            value: _requiresCheck,
            onChanged: (bool value) {
              setState(() {
                _requiresCheck = value;
              });
            },
            // FormFieldの見た目に近づける
            contentPadding: EdgeInsets.zero, 
          ),
          
          if (_requiresCheck)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _checkTextController,
                  decoration: const InputDecoration(
                    labelText: "撮影すべき物体の説明（例: 赤いベンチ）",
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _checkImageURLController,
                        decoration: const InputDecoration(
                          labelText: "見本画像URL（オプション）",
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enabled: !_isUploadingCheckImage,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isUploadingCheckImage
                          ? null
                          : () {
                              // CheckImageUploadViewの代わりにBottomSheetを使用
                              _showCheckImageUploadSheet();
                            },
                      icon: _isUploadingCheckImage
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt),
                      label: Text(_isUploadingCheckImage ? "アップロード中..." : "撮影・選択"),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // 見本画像プレビュー
                if (_checkImageURLController.text.isNotEmpty)
                  Container(
                    alignment: Alignment.center,
                    height: 200,
                    color: Colors.grey[200],
                    child: Text("見本画像プレビュー (${_checkImageURLController.text})", style: TextStyle(color: Colors.grey)),
                  ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                "認証チェックがオフの場合、正解後は画像認証なしで次の問題へ遷移します",
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // MARK: - Helper Widgets
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildHintSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader("ヒント"),
            TextButton.icon(
              onPressed: () => _openHintEditPage(hint: null),
              icon: const Icon(Icons.add_circle, size: 16),
              label: const Text("追加"),
            ),
          ],
        ),
        if (_hints.isEmpty)
          Text(
            "ヒントがありません",
            style: TextStyle(fontSize: 14, color: Colors.grey[600], fontStyle: FontStyle.italic),
          )
        else
          ..._hints.asMap().entries.map((entry) {
            final index = entry.key;
            final hint = entry.value;
            return Dismissible(
              key: ValueKey(hint.id),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) => _deleteHint(index),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: HintRow(
                hint: hint,
                onEdit: () => _openHintEditPage(hint: hint),
              ),
            );
          }).toList(),
      ],
    );
  }

  // MARK: - Check Image Upload Sheet
  
  void _showCheckImageUploadSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => CheckImageUploadSheet(
        onImageSelected: (File imageFile) {
          Navigator.of(context).pop(); // Sheetを閉じる
          _uploadCheckImage(imageFile); // アップロードを開始
        },
      ),
    );
  }
}

// MARK: - HintRow (Swiftの HintRow に相当)

class HintRow extends StatelessWidget {
  final Hint hint;
  final VoidCallback onEdit;

  const HintRow({
    required this.hint,
    required this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hint.content, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            "${hint.timeOffset}分後に表示",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit, color: Colors.blue),
        onPressed: onEdit,
      ),
      onTap: onEdit,
    );
  }
}

// MARK: - CheckImageUploadSheet (Swiftの CheckImageUploadView に相当)

class CheckImageUploadSheet extends StatefulWidget {
  final ValueChanged<File> onImageSelected;

  const CheckImageUploadSheet({required this.onImageSelected, super.key});

  @override
  State<CheckImageUploadSheet> createState() => _CheckImageUploadSheetState();
}

class _CheckImageUploadSheetState extends State<CheckImageUploadSheet> {
  final ImagePicker _picker = ImagePicker();
  File? _tempImage;

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _tempImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _tempImage == null ? "見本画像を選択" : "画像プレビュー",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          if (_tempImage != null)
            Column(
              children: [
                Image.file(
                  _tempImage!,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () => widget.onImageSelected(_tempImage!),
                      child: const Text("この画像を使用"),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        setState(() => _tempImage = null);
                      },
                      child: const Text("別の画像を選択"),
                    ),
                  ],
                ),
              ],
            )
          else
            Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text("カメラで撮影"),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text("フォトライブラリから選択"),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("閉じる"),
          ),
        ],
      ),
    );
  }
}