import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event.dart'; // Eventモデルをインポート
import '../services/firebase_service.dart'; // FirebaseServiceをインポート（仮定）
import 'individual_event_page.dart'; // 遷移先のページをインポート（次のステップで作成予定）

/// プレイヤー名（チーム名）を登録するページ
class PlayerNameRegistrationPage extends StatefulWidget {
  final Event event;

  const PlayerNameRegistrationPage({
    required this.event,
    super.key,
  });

  @override
  State<PlayerNameRegistrationPage> createState() => _PlayerNameRegistrationPageState();
}

class _PlayerNameRegistrationPageState extends State<PlayerNameRegistrationPage> {
  // MARK: - State Properties (Swiftの @State の代替)
  
  final TextEditingController _playerNameController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool _showError = false;
  bool _isNameDuplicate = false;
  // bool _shouldNavigateToEventDetail = false; // Flutterでは直接Navigatorで遷移

  // Firebase Service (仮定)
  final FirebaseService _firebaseService = FirebaseService.instance; 
  
  // MARK: - Lifecycle
  
  @override
  void initState() {
    super.initState();
    // 入力が変更されたときのリスナーを設定（Swiftの .onChange の代替）
    _playerNameController.addListener(_resetDuplicateCheck);
  }

  @override
  void dispose() {
    _playerNameController.removeListener(_resetDuplicateCheck);
    _playerNameController.dispose();
    super.dispose();
  }

  // MARK: - Logic (Swiftの registerPlayerName() に相当)
  
  /// 入力が変更されたら重複チェック状態をリセット
  void _resetDuplicateCheck() {
    if (_isNameDuplicate) {
      setState(() {
        _isNameDuplicate = false;
      });
    }
  }

  /// プレイヤー名を登録し、重複チェックを行う
  Future<void> _registerPlayerName() async {
    final trimmedName = _playerNameController.text.trim();
    
    // 空文字チェック
    if (trimmedName.isEmpty) {
      _showAlertDialog("名前を入力してください");
      return;
    }
    
    // 名前の長さチェック
    if (trimmedName.length > 20) {
      _showAlertDialog("名前は20文字以内で入力してください");
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. 重複チェック（Firebase Serviceが実装されている前提）
      // Swift: await firebaseService.checkPlayerNameDuplicate(...)
      final isDuplicate = await _firebaseService.checkPlayerNameDuplicate(
        playerName: trimmedName,
        eventId: widget.event.id, // DartモデルではidはString
      );

      if (isDuplicate) {
        // 2. 重複あり
        setState(() {
          _isNameDuplicate = true;
          _isLoading = false;
        });
      } else {
        // 3. 登録成功
        
        // 名前を保存 (UserDefaultsの代替)
        final prefs = await SharedPreferences.getInstance();
        final key = "playerName_${widget.event.id}";
        await prefs.setString(key, trimmedName);
        
        // IndividualEventPageへ遷移 (Swiftの navigationDestination に相当)
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => IndividualEventPage(
                event: widget.event,
                // IndividualEventPageに登録された名前を渡す
                playerName: trimmedName, 
              ),
            ),
          );
        }
      }
    } catch (error) {
      // 4. エラー処理
      _showAlertDialog(error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  /// エラーメッセージを表示するためのAlertDialog
  void _showAlertDialog(String message) {
    setState(() {
      _errorMessage = message;
      _showError = true;
    });
    // Swiftの .alert と同じように、状態変更で自動的に表示されるわけではないため、手動で表示
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("エラー"),
        content: Text(_errorMessage ?? "不明なエラーが発生しました"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _showError = false; // エラー表示状態をリセット
              });
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // MARK: - UI Build

  @override
  Widget build(BuildContext context) {
    // Swiftの navigationTitle と navigationBarTitleDisplayMode(.inline) に相当
    return Scaffold(
      appBar: AppBar(
        title: const Text("プレイヤー名登録"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Spacer(),
            
            // イベント名表示
            Column(
              children: [
                Text(
                  widget.event.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28, // title 相当
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "プレイヤー名を登録してください",
                  style: TextStyle(
                    fontSize: 14, // subheadline 相当
                    color: Colors.grey[600], // secondary 相当
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            // 名前入力フィールド
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "プレイヤー名（ニックネーム可）",
                  style: TextStyle(
                    fontSize: 16, // headline 相当
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                
                TextField(
                  controller: _playerNameController,
                  decoration: InputDecoration(
                    labelText: "名前を入力",
                    // Swiftの .textFieldStyle(.roundedBorder) に近いスタイル
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                ),
                
                // 重複エラー表示
                if (_isNameDuplicate)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "この名前は既に登録されています",
                          style: TextStyle(
                            fontSize: 12, // caption 相当
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 40),

            // 登録ボタン
            ElevatedButton(
              onPressed: _playerNameController.text.trim().isEmpty || _isLoading
                  ? null
                  : _registerPlayerName,
              style: ElevatedButton.styleFrom(
                // ボタンの無効化状態の色もSwiftに合わせるために調整可能
                backgroundColor: _playerNameController.text.trim().isEmpty || _isLoading
                    ? Colors.grey // 無効時の色
                    : Colors.blue, // 有効時の色
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "登録して開始",
                      style: TextStyle(
                        fontSize: 18, // headline 相当
                        fontWeight: FontWeight.w600, // semibold 相当
                      ),
                    ),
            ),
            
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// MARK: - Dummy Implementation (このコードは一時的なものです)

/*
// PlayerNameRegistrationPageの動作を確認するために、
// 以下のダミーページとFirebaseServiceが必要になります。

// 1. IndividualEventPage のダミー
class IndividualEventPage extends StatelessWidget {
  final Event event;
  final String playerName;

  const IndividualEventPage({required this.event, required this.playerName, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("イベント詳細")),
      body: Center(
        child: Text("ようこそ、 $playerName さん！\nイベント: ${event.name}"),
      ),
    );
  }
}

// 2. FirebaseService のダミー（重複チェックをシミュレーション）
class FirebaseService {
  static final FirebaseService instance = FirebaseService._();
  FirebaseService._();

  // "TestDuplicate" という名前を重複としてシミュレーションします
  Future<bool> checkPlayerNameDuplicate({required String playerName, required String eventId}) async {
    // 擬似的なネットワーク遅延
    await Future.delayed(const Duration(milliseconds: 800)); 
    return playerName.toLowerCase() == "testduplicate";
  }
}
*/