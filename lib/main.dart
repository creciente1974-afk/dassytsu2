// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_root.dart'; // ★★★ 新しく作成したファイルをインポート ★★★


// Swiftの main() 関数に相当する、Dartのメイン関数
void main() async {
  // 1. Flutterエンジンのバインディングを初期化 (必須)
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Firebaseの初期化 (Swiftの FirebaseApp.configure() に相当)
  try {
    // 既に初期化されている場合はスキップ
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(); 
      print("✅ [main] Firebase 初期化完了");
    } else {
      print("✅ [main] Firebase は既に初期化されています");
    }
    
    // 初期化が確実に完了したことを確認（少し待機してから確認）
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (Firebase.apps.isNotEmpty) {
      try {
        final app = Firebase.app();
        print("✅ [main] Firebase アプリ確認: ${app.name}");
      } catch (e) {
        print("⚠️ [main] Firebase.app()の取得に失敗: $e");
        // アプリは続行（FirebaseServiceが適切に処理する）
      }
    } else {
      print("⚠️ [main] Firebase.appsが空です");
    }
  } catch (e, stackTrace) {
    print("❌ [main] Firebase 初期化に失敗: $e");
    print("❌ [main] スタックトレース: $stackTrace");
    print("⚠️ [main] Firebase機能は使用できませんが、アプリは続行します");
    // Firebase初期化失敗時もアプリは続行（FirebaseServiceが適切にエラーハンドリングする）
  }
  
  // 3. 日付フォーマットのロケールデータを初期化（日本語用）
  try {
    await initializeDateFormatting('ja', null);
    print("✅ [main] 日付フォーマット初期化完了");
  } catch (e) {
    print("⚠️ [main] 日付フォーマット初期化に失敗: $e");
  }
  
  // 4. システム設定（例：画面の向き固定、SwiftのAVAudioSession設定の代わり）
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  print("✅ [main] システム設定完了");
  
  // 5. アプリケーションの実行 (分離した app_root.dart のクラスを呼び出す)
  runApp(const DassyutsuApp()); 
}