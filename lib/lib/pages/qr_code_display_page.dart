// lib/pages/qr_code_display_page.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // QRコード表示パッケージ
import 'package:image_gallery_saver/image_gallery_saver.dart'; // 画像保存パッケージ
import 'package:permission_handler/permission_handler.dart'; // 権限ハンドラー
import 'dart:typed_data'; // 画像バイトデータ用
import 'dart:ui'; // ui.Imageを扱うため
import 'package:flutter/rendering.dart'; // RepaintBoundary用
import 'dart:io';

// --------------------------------------------------------------------------
// QRCodeDisplayPage
// --------------------------------------------------------------------------

class QRCodeDisplayPage extends StatefulWidget {
  // Swiftの qrCodeImage ではなく、生成に必要なデータを受け取る
  final String qrCodeData; // QRコードに埋め込むイベントIDなどを含むデータ
  final String eventName;

  const QRCodeDisplayPage({
    super.key,
    required this.qrCodeData,
    required this.eventName,
  });

  @override
  State<QRCodeDisplayPage> createState() => _QRCodeDisplayPageState();
}

class _QRCodeDisplayPageState extends State<QRCodeDisplayPage> {
  final GlobalKey _qrBoundaryKey = GlobalKey(); // QRコードウィジェットのキャプチャ用
  String _saveAlertMessage = "";
  bool _showSaveAlert = false;

  // MARK: - ギャラリー保存ロジック

  Future<void> _saveQRCode() async {
    // 1. 権限チェックとリクエスト (PHPhotoLibrary.authorizationStatus の代替)
    var status = await Permission.photos.status;
    if (!status.isGranted) {
      status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      // 権限がない場合
      _setAlert(
          "フォトライブラリへのアクセス権限が必要です。",
          "設定から権限を許可してください。"
      );
      return;
    }

    // 2. QRコードウィジェットを画像としてキャプチャ (UIImage生成の代替)
    try {
      final boundary = _qrBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      // 適切な解像度で画像をキャプチャ
      final image = await boundary.toImage(pixelRatio: 3.0); 
      final ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      // 3. 画像をギャラリーに保存
      final result = await ImageGallerySaver.saveImage(
        pngBytes,
        quality: 100,
        name: "${widget.eventName}_QRCode",
      );

      if (result['isSuccess'] == true) {
        _setAlert("保存完了", "QRコードをフォトライブラリに保存しました");
      } else {
        _setAlert("保存失敗", "保存に失敗しました: ${result['errorMessage'] ?? '不明なエラー'}");
      }
    } catch (e) {
      _setAlert("キャプチャエラー", "QRコード画像の生成または保存に失敗しました: $e");
    }
  }

  void _setAlert(String title, String message) {
    if (mounted) {
      setState(() {
        _saveAlertMessage = "$title\n$message";
        _showSaveAlert = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("QRコード"),
        automaticallyImplyLeading: false, // NavigationStack内のデフォルトの戻るボタンを非表示
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // Swiftの dismiss() に相当
            child: const Text("閉じる"),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              
              Text(
                "QRコード",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              Text(
                widget.eventName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // QRコードの表示部分 (キャプチャ対象)
              RepaintBoundary(
                key: _qrBoundaryKey,
                child: Container(
                  width: 300,
                  height: 300,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: QrImageView(
                    data: widget.qrCodeData, // 埋め込む文字列
                    version: QrVersions.auto,
                    size: 268.0,
                    // QRコードは一般的に白黒でコントラストを最大化します
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                "このQRコードを受付で読み取ってください",
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              // ダウンロードボタン
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text("ダウンロード", style: TextStyle(color: Colors.white, fontSize: 16)),
                  onPressed: _saveQRCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
      // Swiftの .alert に相当
      bottomSheet: _showSaveAlert ? _buildAlertSheet() : null,
    );
  }

  // エラー/保存完了メッセージをBottom Sheetで表示する
  Widget _buildAlertSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.1))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "保存",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const Divider(),
          Text(
            _saveAlertMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showSaveAlert = false;
              });
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}