// lib/utils/view_snapshot_helper.dart

import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

/// FlutterのWidgetを画像バイトデータ (Uint8List) に変換するヘルパー
/// Swiftの ViewSnapshotHelper の代替
class ViewSnapshotHelper {
  
  // Swiftと同様、静的メソッドとして提供

  /// 指定された GlobalKey に紐づくウィジェットをキャプチャし、PNGバイトデータとして返します。
  /// 
  /// - Parameters:
  ///   - key: キャプチャ対象のウィジェットにアタッチされている GlobalKey。
  ///   - pixelRatio: 画像の解像度。Swiftの UIScreen.main.scale (デフォルト: 3.0) に相当します。
  /// - Returns: 画像のバイトデータ (Uint8List)。キャプチャ失敗時は null。
  static Future<Uint8List?> snapshotWidget({
    required GlobalKey key,
    double pixelRatio = 3.0,
  }) async {
    // 1. RepaintBoundaryのRenderObjectを取得
    final boundary = key.currentContext?.findRenderObject();
    
    if (boundary == null || boundary is! RenderRepaintBoundary) {
      debugPrint("エラー: GlobalKeyがRenderRepaintBoundaryにアタッチされていません。");
      return null;
    }

    try {
      // 2. RenderObjectをui.Imageに変換
      // Swiftの UIGraphicsImageRenderer.image に相当
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      
      // 3. ui.ImageをByteDataに変換 (UIImageからDataへの変換に相当)
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      // 4. ByteDataをUint8Listとして返す
      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      return null;
      
    } catch (e) {
      debugPrint("ウィジェットのスナップショット生成中にエラーが発生しました: $e");
      return null;
    }
  }
}

// --------------------------------------------------------------------------
// 💡 ViewSnapshotHelperの利用方法
// --------------------------------------------------------------------------
/*
// 例: クリア画面全体をキャプチャするウィジェット（ClearScreenPageなど）

import 'package:flutter/material.dart';
// import './utils/view_snapshot_helper.dart'; // 作成したヘルパーをインポート

class ClearScreenPage extends StatelessWidget {
  // 1. GlobalKeyを作成
  final GlobalKey _captureKey = GlobalKey();

  ClearScreenPage({super.key});

  // 2. キャプチャを実行する関数
  Future<void> _handleShare(BuildContext context) async {
    final Uint8List? imageBytes = await ViewSnapshotHelper.snapshotWidget(key: _captureKey);

    if (imageBytes != null) {
      // 成功: ShareManagerにデータを渡して共有（ShareManagerは別途実装が必要）
      // ShareManager.shared.shareContent(imageBytes: imageBytes, text: "クリアしました", context: context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("画像をキャプチャしました。")));
    } else {
      // 失敗
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("画像のキャプチャに失敗しました。")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("クリア画面")),
      // 3. キャプチャしたいウィジェット全体を RepaintBoundary で囲む
      body: RepaintBoundary(
        key: _captureKey, // ここで GlobalKey をアタッチ
        child: Container(
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("🎉 イベントクリア! 🎉", style: TextStyle(fontSize: 24)),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () => _handleShare(context),
                child: const Text("結果をシェア"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/