import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../firebase_service.dart';

/// プレイヤー名を編集・保存するページ
class PlayerNameEditPage extends StatefulWidget {
  const PlayerNameEditPage({super.key});

  @override
  State<PlayerNameEditPage> createState() => _PlayerNameEditPageState();
}

class _PlayerNameEditPageState extends State<PlayerNameEditPage> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, String> _playerNames = {}; // eventId -> playerName
  Map<String, TextEditingController> _controllers = {}; // eventId -> TextEditingController
  List<String> _eventIds = [];

  @override
  void initState() {
    super.initState();
    _loadPlayerNames();
  }

  @override
  void dispose() {
    // すべてのコントローラーを破棄
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    super.dispose();
  }

  /// すべてのイベントのプレイヤー名を読み込む
  Future<void> _loadPlayerNames() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys();
      
      // "playerName_{eventId}" の形式のキーを抽出
      final playerNameKeys = allKeys.where((key) => key.startsWith('playerName_')).toList();
      
      Map<String, String> playerNames = {};
      List<String> eventIds = [];
      
      for (final key in playerNameKeys) {
        final eventId = key.replaceFirst('playerName_', '');
        final playerName = prefs.getString(key);
        if (playerName != null && playerName.isNotEmpty) {
          playerNames[eventId] = playerName;
          eventIds.add(eventId);
          // コントローラーを作成
          if (!_controllers.containsKey(eventId)) {
            _controllers[eventId] = TextEditingController(text: playerName);
          } else {
            _controllers[eventId]!.text = playerName;
          }
        }
      }
      
      setState(() {
        _playerNames = playerNames;
        _eventIds = eventIds;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'プレイヤー名の読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  /// プレイヤー名を保存
  Future<void> _savePlayerName(String eventId, String playerName) async {
    if (playerName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プレイヤー名を入力してください')),
      );
      return;
    }

    if (playerName.trim().length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プレイヤー名は20文字以内で入力してください')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "playerName_$eventId";
      await prefs.setString(key, playerName.trim());
      
      setState(() {
        _playerNames[eventId] = playerName.trim();
        // コントローラーのテキストも更新
        if (_controllers.containsKey(eventId)) {
          _controllers[eventId]!.text = playerName.trim();
        }
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プレイヤー名を保存しました')),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = '保存に失敗しました: $e';
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    }
  }

  /// プレイヤー名を削除
  Future<void> _deletePlayerName(String eventId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = "playerName_$eventId";
      await prefs.remove(key);
      
      setState(() {
        _playerNames.remove(eventId);
        _eventIds.remove(eventId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('プレイヤー名を削除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プレイヤー名変更'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPlayerNames,
                        child: const Text('再試行'),
                      ),
                    ],
                  ),
                )
              : _eventIds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_outline, size: 60, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            '登録されているプレイヤー名がありません',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'イベントに参加すると、ここでプレイヤー名を編集できます',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _eventIds.length,
                      itemBuilder: (context, index) {
                        final eventId = _eventIds[index];
                        final playerName = _playerNames[eventId] ?? '';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(
                              'イベントID: $eventId',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextField(
                                controller: _controllers[eventId] ?? TextEditingController(text: playerName),
                                decoration: InputDecoration(
                                  labelText: 'プレイヤー名',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.save),
                                    onPressed: _isSaving
                                        ? null
                                        : () {
                                            final controller = _controllers[eventId];
                                            if (controller != null) {
                                              _savePlayerName(eventId, controller.text);
                                            }
                                          },
                                    tooltip: '保存',
                                  ),
                                ),
                                onSubmitted: (value) {
                                  _savePlayerName(eventId, value);
                                },
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('プレイヤー名を削除'),
                                    content: Text('「$playerName」を削除しますか？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('キャンセル'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deletePlayerName(eventId);
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('削除'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              tooltip: '削除',
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

