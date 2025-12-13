// lib/app_root.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 必要なファイル（ContentView, LoginView）をインポート
// import 'content_view.dart'; // ★ 実際のファイル名に合わせて修正してください ★
// import 'login_view.dart'; // ★ 実際のファイル名に合わせて修正してください ★

// --- 仮定のビュー（LoginViewとContentViewがまだない場合用） ---
// 実際は上記のインポートが成功すれば、このダミーは不要です。
class ContentView extends StatelessWidget {
  const ContentView({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('コンテンツ画面')));
  }
}
class LoginView extends StatelessWidget {
  const LoginView({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('ログイン画面')));
  }
}
// ----------------------------------------------------

// 1. アプリケーションの基本構造 (SwiftUIの struct dassyutsuApp: App の代わり)
class DassyutsuApp extends StatelessWidget {
  const DassyutsuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dassyutsu',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      // Homeに「どの画面から始めるか」を判断するウィジェットを指定
      home: const RootScreenDecider(),
    );
  }
}

// 2. ルートビューを決定するロジック (SwiftUIの body 内の切り替えロジックの代わり)
class RootScreenDecider extends StatefulWidget {
  const RootScreenDecider({super.key});

  @override
  State<RootScreenDecider> createState() => _RootScreenDeciderState();
}

class _RootScreenDeciderState extends State<RootScreenDecider> {
  // ログイン状態を保持 (null: チェック中, true: ログイン済み, false: 未ログイン)
  bool? _isLoggedIn; 

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // 画面が表示される前に、ログイン状態の確認を開始
  }

  // ログイン状態を確認する関数 (UserDefaults の代わりに SharedPreferences を使用)
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    // "userDeviceInfo" キーのデータが存在するかチェック
    final userInfo = prefs.getString('userDeviceInfo'); 
    
    if (mounted) { // ウィジェットがまだ画面上にあるか確認
      setState(() {
        _isLoggedIn = userInfo != null;
        print("💡 [RootScreenDecider] ログイン状態: $_isLoggedIn");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ログイン状態のチェック中はローディングを表示
    if (_isLoggedIn == null) {
      // 
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    // ログイン状態に基づき、ルートビューを切り替える
    if (_isLoggedIn == true) {
      // ログイン済みの場合: ContentView
      return const ContentView();
    } else {
      // 未ログインの場合: LoginView
      return const LoginView();
    }
  }
}