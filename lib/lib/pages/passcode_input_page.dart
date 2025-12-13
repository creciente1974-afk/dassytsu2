import 'package:flutter/material.dart';

/// イベント編集・作成用の暗証番号入力ページ (モーダルとして使用)
class PasscodeInputPage extends StatefulWidget {
  // 認証成功時に呼び出されるコールバック。認証された暗証番号を返す。
  final ValueChanged<String> onVerified;
  
  // イベント固有の暗証番号（編集時のみ使用）。nullの場合、新規作成用の汎用コードをチェック。
  final String? requiredPasscode;

  const PasscodeInputPage({
    required this.onVerified,
    this.requiredPasscode,
    super.key,
  });

  @override
  State<PasscodeInputPage> createState() => _PasscodeInputPageState();
}

class _PasscodeInputPageState extends State<PasscodeInputPage> {
  // MARK: - State Properties (Swiftの @State と @Binding の代替)
  
  final TextEditingController _passcodeInputController = TextEditingController();
  
  bool _showError = false;
  String _errorMessage = "";
  bool _isValidating = false;
  
  // Swiftの localPasscodes に相当する、新規作成用のローカル認証コードリスト
  final List<String> _localPasscodes = const ["1115", "1116"];
  
  // MARK: - Logic (Swiftの verifyPasscode() に相当)
  
  Future<void> _verifyPasscode() async {
    if (_isValidating) return;
    
    setState(() {
      _isValidating = true;
      _showError = false;
      _errorMessage = "";
    });

    // 入力された暗証番号をトリム
    final trimmedPasscode = _passcodeInputController.text.trim();
    
    if (trimmedPasscode.isEmpty) {
      setState(() {
        _isValidating = false;
        _showError = true;
        _errorMessage = "暗証番号を入力してください";
      });
      return;
    }

    bool isValid = false;
    
    // イベント固有の暗証番号が指定されている場合 (編集モード)
    if (widget.requiredPasscode != null) {
      isValid = trimmedPasscode == widget.requiredPasscode;
      if (!isValid) {
        _errorMessage = "暗証番号が正しくありません。このイベントを作成時に使用した暗証番号を入力してください。";
      }
    } else {
      // 新規作成モード: ローカルコードリストをチェック
      isValid = _localPasscodes.contains(trimmedPasscode);
      if (!isValid) {
        _errorMessage = "暗証番号が無効です。有効な暗証番号を入力してください";
      }
    }
    
    // 処理完了後のUI更新
    setState(() {
      _isValidating = false;
      if (isValid) {
        // 認証成功
        _showError = false;
        _passcodeInputController.clear();
        
        // onVerified コールバックを実行し、画面を閉じる (dismiss() の代替)
        widget.onVerified(trimmedPasscode);
        Navigator.of(context).pop();
      } else {
        // 認証失敗
        _showError = true;
        _passcodeInputController.clear();
      }
    });
  }
  
  // MARK: - UI Build

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("暗証番号認証"),
        // Swiftの navigationBarTitleDisplayMode(.inline) に相当
        centerTitle: true, 
        actions: [
          // Swiftの ToolbarItem(placement: .navigationBarTrailing) Button("キャンセル") に相当
          TextButton(
            onPressed: () {
              _passcodeInputController.clear();
              // 画面を閉じる (dismiss() の代替)
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
          // Swiftの VStack(spacing: 24) に相当
          children: <Widget>[
            // Image(systemName: "lock.shield") に相当
            Icon(
              Icons.lock_outline, 
              size: 50,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            
            // Text("暗証番号認証") に相当
            const Text(
              "暗証番号認証",
              style: TextStyle(
                fontSize: 22, // title2 相当
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // 説明テキスト
            Text(
              widget.requiredPasscode != null 
                  ? "このイベントを編集するには、作成時に使用した暗証番号が必要です" 
                  : "イベント編集・作成には暗証番号が必要です",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, // subheadline 相当
                color: Colors.grey[600], // secondary 相当
              ),
            ),
            const SizedBox(height: 24),
            
            // TextField("暗証番号", text: $passcodeInput) に相当
            TextField(
              controller: _passcodeInputController,
              decoration: InputDecoration(
                labelText: "暗証番号",
                // Swiftの .textFieldStyle(.roundedBorder) に近いスタイル
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              keyboardType: TextInputType.text,
              obscureText: true, // パスワードとして非表示にする
              onSubmitted: (_) => _verifyPasscode(),
            ),
            const SizedBox(height: 12),
            
            // エラーメッセージ
            if (_showError)
              Text(
                _errorMessage.isEmpty ? "暗証番号が正しくありません" : _errorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12, // caption 相当
                ),
              ),
            const SizedBox(height: 24),
            
            // Button("認証") に相当
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_passcodeInputController.text.isEmpty || _isValidating) 
                    ? null 
                    : _verifyPasscode,
                // Swiftの .buttonStyle(.borderedProminent) に近いスタイル
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isValidating 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ) 
                    : const Text(
                        "認証",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            
            // Swiftの ProgressView() に相当 (ボタン内で処理済み)
            
            const Spacer(),
          ],
        ),
      ),
    );
  }
}