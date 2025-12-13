import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 管理者ページへのログイン認証を行うページ（モーダルとして使用）
class AdminLoginPage extends StatefulWidget {
  // 認証成功時に呼び出されるコールバック
  final ValueChanged<bool> onLoginSuccess;

  const AdminLoginPage({
    required this.onLoginSuccess,
    super.key,
  });

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  // MARK: - State Properties
  
  final TextEditingController _passwordInputController = TextEditingController();
  
  bool _showError = false;
  String _errorMessage = "";
  
  // 管理者ページへの固定暗証番号: 1234
  final String _adminPasscode = "1234";
  
  // MARK: - Logic (Swiftの checkPassword() に相当)
  
  /// 管理者ページログインの認証ロジック
  Future<void> _checkPassword() async {
    setState(() {
      _showError = false;
      _errorMessage = "";
    });

    final inputPasscode = _passwordInputController.text.trim();
    
    // ローカル判定: 固定値「1234」と比較
    final isValid = inputPasscode == _adminPasscode;
    
    if (isValid) {
      // 認証成功

      // 暗証番号をSharedPreferencesに保存（Swiftの UserDefaults.standard の代替）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("currentPasscode", inputPasscode);
      
      setState(() {
        _showError = false;
      });
      _passwordInputController.clear();
      
      // 認証成功のコールバックを実行
      widget.onLoginSuccess(true);
      
      // 画面を閉じる (dismiss() と isPresented = false の代替)
      if (mounted) {
        Navigator.of(context).pop();
      }
      
    } else {
      // 認証失敗
      setState(() {
        _showError = true;
        _errorMessage = "パスコードが正しくありません";
      });
      _passwordInputController.clear();
    }
  }
  
  // MARK: - UI Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("管理者ログイン"),
        centerTitle: true, 
        actions: [
          TextButton(
            onPressed: () {
              // 画面を閉じる (キャンセル)
              _passwordInputController.clear();
              setState(() {
                _showError = false;
              });
              Navigator.of(context).pop();
            },
            child: const Text("キャンセル"),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.lock_shield, 
              size: 50,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            
            const Text(
              "管理者ログイン",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // SecureField("パスコード", text: $passwordInput) に相当
            TextField(
              controller: _passwordInputController,
              decoration: InputDecoration(
                labelText: "パスコード",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              keyboardType: TextInputType.text,
              obscureText: true, // パスコードを非表示にする
              onSubmitted: (_) => _checkPassword(),
            ),
            const SizedBox(height: 12),
            
            // エラーメッセージ
            if (_showError)
              Text(
                _errorMessage.isEmpty ? "パスコードが正しくありません" : _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            const SizedBox(height: 24),
            
            // ログインボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _passwordInputController.text.isEmpty 
                    ? null 
                    : _checkPassword,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "ログイン",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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