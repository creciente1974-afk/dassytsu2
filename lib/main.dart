// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'app_root.dart'; // ★★★ 新しく作成したファイルをインポート ★★★


// Swiftの main() 関数に相当する、Dartのメイン関数
void main() async {
  // 1. Flutterエンジンのバインディングを初期化 (必須)
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Firebaseの初期化 (Swiftの FirebaseApp.configure() に相当)
  try {
    // 実際のプロジェクトの設定に合わせて調整してください
    await Firebase.initializeApp(); 
    print("✅ [main] Firebase 初期化完了");
  } catch (e) {
    print("⚠️ [main] Firebase 初期化に失敗: $e");
  }
  
  // 3. システム設定（例：画面の向き固定、SwiftのAVAudioSession設定の代わり）
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  print("✅ [main] システム設定完了");
  
  // 4. アプリケーションの実行 (分離した app_root.dart のクラスを呼び出す)
  runApp(const DassyutsuApp()); 
}