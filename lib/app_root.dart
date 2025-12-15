// lib/app_root.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 必要なファイル（ContentView, LoginView）をインポート
import 'content_view.dart';
import 'login_view.dart';

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
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // "userDeviceInfo" キーのデータが存在するかチェック
      final userInfo = prefs.getString('userDeviceInfo'); 
      
      if (mounted) { // ウィジェットがまだ画面上にあるか確認
        setState(() {
          _isLoggedIn = userInfo != null;
          print("💡 [RootScreenDecider] ログイン状態: $_isLoggedIn");
        });
      }
    } catch (e, stackTrace) {
      print("❌ [RootScreenDecider] ログイン状態確認エラー: $e");
      print("❌ [RootScreenDecider] スタックトレース: $stackTrace");
      // エラーが発生した場合は未ログインとして扱う
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ログイン状態のチェック中はローディングを表示
    if (_isLoggedIn == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    // ログイン状態に基づき、ルートビューを切り替える
    try {
      if (_isLoggedIn == true) {
        // ログイン済みの場合: ContentView
        print("🔄 [RootScreenDecider] ContentViewを表示します");
        return const ContentView();
      } else {
        // 未ログインの場合: LoginView
        return LoginView(onLoginSuccess: _checkLoginStatus);
      }
    } catch (e, stackTrace) {
      print("❌ [RootScreenDecider] ビルドエラー: $e");
      print("❌ [RootScreenDecider] スタックトレース: $stackTrace");
      // エラーが発生した場合はエラー画面を表示
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('アプリの起動に失敗しました'),
              const SizedBox(height: 8),
              Text('エラー: $e', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
  }
}