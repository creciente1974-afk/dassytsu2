// lib/content_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'event_list_page.dart';

class ContentView extends StatelessWidget {
  const ContentView({super.key});

  @override
  Widget build(BuildContext context) {
    try {
      print("🔄 [ContentView] EventListPageを構築中...");
      return const EventListPage();
    } catch (e, stackTrace) {
      debugPrint("❌ [ContentView] ビルドエラー: $e");
      debugPrint("❌ [ContentView] スタックトレース: $stackTrace");
      // エラーが発生した場合はエラー画面を表示
      return Scaffold(
        appBar: AppBar(title: const Text('エラー')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('画面の読み込みに失敗しました'),
              const SizedBox(height: 8),
              Text('エラー: $e', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
  }
}