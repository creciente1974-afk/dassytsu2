// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // debugPrint用
import 'package:flutter/services.dart';
import 'dart:ui';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_root.dart'; // ★★★ 新しく作成したファイルをインポート ★★★
import 'config/app_config.dart'; // アプリ設定
import 'services/revenuecat_service.dart'; // RevenueCatサービスのインポート


// Swiftの main() 関数に相当する、Dartのメイン関数
void main() async {
  // デバッグログのテスト
  debugPrint('🚀 [main] アプリが起動しました');
  
  // 1. Flutterエンジンのバインディングを初期化 (必須)
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('🚀 [main] WidgetsFlutterBinding初期化完了');
  
  // 2. Firebaseの初期化 (Swiftの FirebaseApp.configure() に相当)
  try {
    // 既に初期化されている場合はスキップ
    if (Firebase.apps.isEmpty) {
      // macOSの場合は明示的なオプションで初期化
      if (Platform.isMacOS) {
        final options = FirebaseOptions(
          apiKey: 'AIzaSyAiu1LnKFkDLroxfLJLXxjWEY3lvwZ8-as',
          appId: '1:245139907628:ios:e187581a13a65a02eddd89', // iOS app IDを再利用
          messagingSenderId: '245139907628',
          projectId: 'dassyutsu2',
          storageBucket: 'dassyutsu2.firebasestorage.app',
          databaseURL: 'https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app',
        );
        await Firebase.initializeApp(options: options);
        print("✅ [main] Firebase 初期化完了 (macOS - 明示的オプション)");
      } else {
        await Firebase.initializeApp(); 
        print("✅ [main] Firebase 初期化完了");
      }
    } else {
      print("✅ [main] Firebase は既に初期化されています");
    }
    
    // 初期化が確実に完了したことを確認（少し待機してから確認）
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (Firebase.apps.isNotEmpty) {
      try {
        final app = Firebase.app();
        print("✅ [main] Firebase アプリ確認: ${app.name}");
        
        // 匿名認証を試みる（Firebase Realtime Databaseのアクセスに必要かもしれない）
        try {
          // 既に認証されているか確認
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            print("✅ [main] 既に認証済み: ${currentUser.uid} (匿名: ${currentUser.isAnonymous})");
          } else {
            print("🔍 [main] 認証されていないため、匿名認証を試みます...");
            // リトライロジックを追加（最大3回）
            UserCredential? userCredential;
            for (int i = 0; i < 3; i++) {
              try {
                userCredential = await FirebaseAuth.instance.signInAnonymously().timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    throw TimeoutException('匿名認証がタイムアウトしました');
                  },
                );
                print("✅ [main] 匿名認証成功: ${userCredential.user?.uid}");
                print("   - 匿名ユーザー: ${userCredential.user?.isAnonymous}");
                print("   - 認証プロバイダー: ${userCredential.user?.providerData.map((p) => p.providerId).join(', ')}");
                break; // 成功したらループを抜ける
              } catch (retryError) {
                print("⚠️ [main] 匿名認証リトライ ${i + 1}/3 失敗: $retryError");
                if (i < 2) {
                  // 最後の試行でない場合、少し待ってからリトライ
                  await Future.delayed(const Duration(seconds: 2));
                } else {
                  // 最後の試行でも失敗した場合、エラーを再スロー
                  rethrow;
                }
              }
            }
          }
        } catch (authError) {
          print("❌ [main] 匿名認証最終失敗: $authError");
          print("   - エラータイプ: ${authError.runtimeType}");
          print("   - エラー詳細: $authError");
          print("   ⚠️ 重要: 匿名認証が失敗したため、認証ベースのルールではデータベースにアクセスできません");
          print("   💡 対処法:");
          print("   1. Firebase Console → Authentication → Sign-in method で匿名認証が有効か確認");
          print("   2. Google Cloud Console → API とサービス → 有効なAPIとサービス で「Identity Toolkit API」が有効か確認");
          print("   3. ネットワーク接続を確認");
          // 匿名認証が失敗してもアプリは続行（エラーメッセージを表示）
        }
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
  
  // 3. RevenueCatの初期化（設定で有効な場合のみ）
  if (AppConfig.useRevenueCat) {
    try {
      await RevenueCatService().initialize();
      print("✅ [main] RevenueCat初期化完了");
    } catch (e, stackTrace) {
      print("❌ [main] RevenueCat初期化に失敗: $e");
      print("❌ [main] スタックトレース: $stackTrace");
      print("⚠️ [main] サブスクリプション機能は使用できませんが、アプリは続行します");
      // RevenueCat初期化失敗時もアプリは続行
    }
  } else {
    print("ℹ️ [main] RevenueCatは設定により無効化されています");
  }
  
  // 4. 日付フォーマットのロケールデータを初期化（日本語用）
  try {
    await initializeDateFormatting('ja', null);
    print("✅ [main] 日付フォーマット初期化完了");
  } catch (e) {
    print("⚠️ [main] 日付フォーマット初期化に失敗: $e");
  }
  
  // 5. システム設定（例：画面の向き固定、SwiftのAVAudioSession設定の代わり）
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  print("✅ [main] システム設定完了");
  
  // 6. グローバルエラーハンドラーを設定（未処理のエラーをキャッチ）
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("❌ [FlutterError] 未処理のエラー: ${details.exception}");
    debugPrint("❌ [FlutterError] スタックトレース: ${details.stack}");
  };
  
  // 7. プラットフォーム固有のエラーハンドラー（非同期エラーなど）
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("❌ [PlatformError] プラットフォームエラー: $error");
    debugPrint("❌ [PlatformError] スタックトレース: $stack");
    return true; // エラーを処理したことを示す
  };
  
  print("✅ [main] エラーハンドラー設定完了");
  
  // 8. アプリケーションの実行 (分離した app_root.dart のクラスを呼び出す)
  runApp(const DassyutsuApp()); 
}