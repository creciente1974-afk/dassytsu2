// lib/utils/share_manager.dart

import 'dart:io';
import 'dart:typed_data'; // UIImageのデータ（バイト列）に相当
import 'package:flutter/widgets.dart'; // BuildContextとUIImageの代わりにUint8Listを使用
import 'package:path_provider/path_provider.dart'; // 一時ファイルのパスを取得
import 'package:share_plus/share_plus.dart'; // シェア機能

/// SNSシェア機能を管理するクラス (ShareManager.swiftの移植)
class ShareManager {
  
  // Swiftと同様、シングルトンパターンを使用
  static final ShareManager _instance = ShareManager._internal();
  static ShareManager get shared => _instance;
  
  ShareManager._internal();

  /// 画像とテキストを含むコンテンツを、システムシェアシートを表示して共有します。
  /// 
  /// Flutterでは、画像共有に一時的なファイルパスが必要です。
  /// 
  /// - Parameters:
  ///   - imageBytes: 共有する画像のバイトデータ (PNG/JPEGなど). Swiftの UIImage データに相当。
  ///   - text: 共有するテキスト。
  ///   - context: シェアシートを表示するための BuildContext (特にiPadでの位置指定に必要)。
  ///   - onComplete: シェアが完了したかどうかを通知するコールバック。
  Future<void> shareContent({
    required Uint8List imageBytes,
    required String text,
    required BuildContext context, // Flutterでシェアシートを表示するために必要
    Function(bool completed)? onComplete,
  }) async {
    // 1. 画像データを一時ファイルとして保存
    String tempFilePath = '';
    try {
      // 一時ディレクトリを取得
      final tempDir = await getTemporaryDirectory();
      
      // 一意なファイル名を生成
      final fileName = 'share_image_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      
      // バイトデータをファイルに書き込む
      await file.writeAsBytes(imageBytes);
      tempFilePath = file.path;

      // 2. share_plusを使用して共有シートを表示 (UIActivityViewControllerの代替)
      final box = context.findRenderObject() as RenderBox?;
      
      // Share.shareXFiles を使用して画像とテキストを同時に共有
      await Share.shareXFiles(
        [XFile(tempFilePath)], // 共有する画像ファイル
        text: text,             // 共有するテキスト
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size, // iPad対応
      );

      // share_plusは完了したかどうかを直接返さないため、常に true と見なすか、
      // 適切な完了ハンドリングを別途実装する必要があります。
      // Swiftの completionWithItemsHandler の動作を完全に再現することは難しいです。
      onComplete?.call(true); 

    } catch (e) {
      debugPrint('シェア中にエラーが発生しました: $e');
      onComplete?.call(false);
    } finally {
      // 3. 一時ファイルをクリーンアップ
      if (tempFilePath.isNotEmpty) {
        try {
          final file = File(tempFilePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          debugPrint('一時ファイルの削除中にエラーが発生しました: $e');
        }
      }
    }
  }
  
  // テキストのみを共有する簡略版（ClearViewなどで画像がない場合のため）
  Future<void> shareText({
    required String text,
    required BuildContext context,
  }) async {
    try {
      final box = context.findRenderObject() as RenderBox?;
      
      // iPadなどで位置指定が必要な場合のみ設定
      Rect? sharePositionOrigin;
      if (box != null) {
        sharePositionOrigin = box.localToGlobal(Offset.zero) & box.size;
      }
      
      await Share.share(
        text,
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('テキストシェア中にエラーが発生しました: $e');
      rethrow; // エラーを呼び出し元に伝播
    }
  }
}

// --------------------------------------------------------------------------
// 💡 ShareManagerの利用方法 (例: クリア画面のボタンを押したとき)
// --------------------------------------------------------------------------
/*
// 画面のキャプチャ（画像データUint8Listの取得）
Future<Uint8List> _captureScreen() async {
  // ... 画面キャプチャロジック (RepaintBoundaryを使用)
  // 例としてダミーデータを返します
  return Uint8List(0); // 実際の画像バイトデータに置き換えてください
}

// ShareManagerの使用例
void _handleShare(BuildContext context) async {
  final imageBytes = await _captureScreen();
  const shareText = "脱出ゲームをクリアしました！ #dassyutsu";

  await ShareManager.shared.shareContent(
    imageBytes: imageBytes,
    text: shareText,
    context: context,
    onComplete: (completed) {
      if (completed) {
        print("シェアが完了しました");
      } else {
        print("シェアがキャンセルまたは失敗しました");
      }
    },
  );
}
*/