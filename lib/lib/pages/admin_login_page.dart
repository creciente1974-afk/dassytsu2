import 'package:flutter/material.dart';

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
  // MARK: - Logic
  
  /// 管理者ページログインの認証ロジック
  /// 暗証番号認証は削除され、直接認証成功として扱う
  void _proceedToAdmin() {
    // 暗証番号認証をスキップし、直接認証成功として扱う
    // 認証成功のコールバックを実行
    widget.onLoginSuccess(true);
    
    // 画面を閉じる (dismiss() と isPresented = false の代替)
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
  
  // MARK: - UI Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("管理者ページ"),
        centerTitle: true, 
        actions: [
          TextButton(
            onPressed: () {
              // 画面を閉じる (キャンセル)
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
              Icons.lock, 
              size: 50,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            
            const Text(
              "管理者ページ",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            const Text(
              "管理者ページへ進みます",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            
            // 管理者ページへ進むボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _proceedToAdmin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "管理者ページへ",
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