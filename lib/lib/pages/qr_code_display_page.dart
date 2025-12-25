// lib/pages/qr_code_display_page.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart'; // QRコード表示パッケージ
import 'package:image_gallery_saver/image_gallery_saver.dart'; // 画像保存パッケージ
import 'package:permission_handler/permission_handler.dart'; // 権限ハンドラー
import 'dart:typed_data'; // 画像バイトデータ用
import 'dart:ui'; // ui.Imageを扱うため
import 'package:flutter/rendering.dart'; // RepaintBoundary用
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart'; // デバイス情報取得用
import 'package:flutter/services.dart'; // MethodChannel用
import 'package:path_provider/path_provider.dart'; // 一時ファイル/ディレクトリ取得

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

class _QRCodeDisplayPageState extends State<QRCodeDisplayPage> with WidgetsBindingObserver {
  final GlobalKey _qrBoundaryKey = GlobalKey(); // QRコードウィジェットのキャプチャ用
  String _saveAlertMessage = "";
  bool _showSaveAlert = false;
  bool _needsPermission = false; // 権限が必要な場合のフラグ

  @override
  void initState() {
    super.initState();
    // アプリがフォアグラウンドに戻ったときに権限を再チェック
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // アプリがフォアグラウンドに戻ったとき（設定アプリから戻ってきたとき）
    if (state == AppLifecycleState.resumed && _needsPermission) {
      // 権限を再チェック
      _checkPermissionAfterReturn();
    }
  }

  /// 設定アプリから戻ってきた後に権限を再チェック
  Future<void> _checkPermissionAfterReturn() async {
    try {
      final permission = await _getPhotoPermission();
      final status = await permission.status;
      
      debugPrint("📱 [QRCodeDisplayPage] アプリに戻りました。権限の状態: $status");
      
      if (status.isGranted && mounted) {
        // 権限が許可された場合、アラートを閉じて保存を再試行
        debugPrint("✅ [QRCodeDisplayPage] 権限が許可されました: $permission");
        setState(() {
          _showSaveAlert = false;
          _needsPermission = false;
        });
        // 自動的に保存を再試行
        _saveQRCode();
      } else if (mounted) {
        // まだ権限がない場合、メッセージを更新
        debugPrint("⚠️ [QRCodeDisplayPage] まだ権限が許可されていません: $status");
        // 再度権限が必要であることを通知
        _setPermissionAlert(
          "まだ権限が許可されていません。\n設定アプリで権限を許可してください。"
        );
      }
    } catch (e) {
      debugPrint("❌ [QRCodeDisplayPage] 権限チェックエラー: $e");
    }
  }

  // MARK: - ギャラリー保存ロジック

  /// プラットフォーム別の適切な権限を取得
  /// image_gallery_saver は Permission.photos を使用する
  Future<Permission> _getPhotoPermission() async {
    if (Platform.isAndroid) {
      // Android 13 (API 33) 以降は READ_MEDIA_IMAGES が必要
      // permission_handlerでは Permission.photos が READ_MEDIA_IMAGES に対応
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        // Android 13以降: Permission.photos が READ_MEDIA_IMAGES に対応
        return Permission.photos;
      } else {
        // Android 12以前: storage 権限が必要
        // image_gallery_saver が適切に処理する
        return Permission.storage;
      }
    } else {
      // iOS: Permission.photos を使用
      // NSPhotoLibraryAddUsageDescription が設定されていれば、
      // 画像を追加するだけの権限として動作する
      // ただし、permission_handler では Permission.photos を使用する必要がある
      return Permission.photos;
    }
  }

  Future<void> _saveQRCode() async {
    // ローディング表示
    if (mounted) {
      setState(() {
        _showSaveAlert = true;
        _saveAlertMessage = "保存中...";
      });
    }

    try {
      // 注意: image_gallery_saverは内部的に権限をリクエストするため、
      // permission_handlerで事前にリクエストすると競合する可能性があります。
      // そのため、直接保存を試みて、エラーが発生した場合にのみ権限をチェックします。

      // 2. レンダリング完了を待つ
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. QRコードウィジェットを画像としてキャプチャ
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject();
      if (boundary == null || boundary is! RenderRepaintBoundary) {
        _setAlert("エラー", "QRコード画像の取得に失敗しました。もう一度お試しください。");
        return;
      }

      // 適切な解像度で画像をキャプチャ
      final image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      
      if (byteData == null) {
        _setAlert("エラー", "画像データの変換に失敗しました。");
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 4. 一時ファイルに保存してからギャラリーに保存（一般的なパターン）
      String tempFilePath = '';
      try {
        // 一時ディレクトリを取得
        final tempDir = await getTemporaryDirectory();
        
        // 一意なファイル名を生成
        final fileName = '${widget.eventName}_QRCode_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File('${tempDir.path}/$fileName');
        
        // バイトデータを一時ファイルに書き込む
        await file.writeAsBytes(pngBytes);
        tempFilePath = file.path;
        
        debugPrint("📱 [QRCodeDisplayPage] 一時ファイルに保存: $tempFilePath");
        
        // 5. 一時ファイルからギャラリーに保存
        // image_gallery_saverが内部的に権限をリクエストします
        final result = await ImageGallerySaver.saveFile(
          tempFilePath,
          name: "${widget.eventName}_QRCode",
        );

        // デバッグログ
        debugPrint("📱 [QRCodeDisplayPage] QRコード保存結果: $result");

        if (result['isSuccess'] == true) {
          final filePath = result['filePath'] ?? '';
          _setAlert(
            "保存完了", 
            "QRコードをフォトライブラリに保存しました。\n${filePath.isNotEmpty ? '保存先: $filePath' : ''}"
          );
        } else {
          final errorMessage = result['errorMessage'] ?? result['error'] ?? '不明なエラー';
          debugPrint("❌ [QRCodeDisplayPage] QRコード保存エラー: $errorMessage");
          
          // エラーが権限関連の場合、権限をチェック
          if (errorMessage.toString().toLowerCase().contains('permission') || 
              errorMessage.toString().toLowerCase().contains('権限') ||
              errorMessage.toString().toLowerCase().contains('denied')) {
            // 権限をチェック
            final permission = await _getPhotoPermission();
            final status = await permission.status;
            debugPrint("📱 [QRCodeDisplayPage] 権限エラー検出。権限の状態: $status");
            
            if (status.isPermanentlyDenied) {
              _setPermissionAlert("フォトライブラリへのアクセス権限が拒否されています。\n設定アプリから権限を許可してください。");
            } else {
              _setPermissionAlert("フォトライブラリへのアクセス権限が必要です。\n設定から権限を許可してください。");
            }
          } else {
            _setAlert("保存失敗", "保存に失敗しました: $errorMessage");
          }
        }
      } catch (e) {
        debugPrint("❌ [QRCodeDisplayPage] 一時ファイル保存エラー: $e");
        // 一時ファイルの保存に失敗した場合、直接バイトデータで保存を試みる
        try {
          debugPrint("📱 [QRCodeDisplayPage] 直接バイトデータで保存を試みます...");
          final result = await ImageGallerySaver.saveImage(
            pngBytes,
            quality: 100,
            name: "${widget.eventName}_QRCode",
          );
          
          if (result['isSuccess'] == true) {
            final filePath = result['filePath'] ?? '';
            _setAlert(
              "保存完了", 
              "QRコードをフォトライブラリに保存しました。\n${filePath.isNotEmpty ? '保存先: $filePath' : ''}"
            );
          } else {
            final errorMessage = result['errorMessage'] ?? result['error'] ?? '不明なエラー';
            debugPrint("❌ [QRCodeDisplayPage] 直接保存も失敗: $errorMessage");
            
            // エラーが権限関連の場合、権限をチェック
            if (errorMessage.toString().toLowerCase().contains('permission') || 
                errorMessage.toString().toLowerCase().contains('権限') ||
                errorMessage.toString().toLowerCase().contains('denied')) {
              // 権限をチェック
              final permission = await _getPhotoPermission();
              final status = await permission.status;
              debugPrint("📱 [QRCodeDisplayPage] 権限エラー検出。権限の状態: $status");
              
              if (status.isPermanentlyDenied) {
                _setPermissionAlert("フォトライブラリへのアクセス権限が拒否されています。\n設定アプリから権限を許可してください。");
              } else {
                _setPermissionAlert("フォトライブラリへのアクセス権限が必要です。\n設定から権限を許可してください。");
              }
            } else {
              _setAlert("保存失敗", "保存に失敗しました: $errorMessage");
            }
          }
        } catch (e2) {
          debugPrint("❌ [QRCodeDisplayPage] 直接保存もエラー: $e2");
          
          // エラーが権限関連の場合、権限をチェック
          if (e2.toString().toLowerCase().contains('permission') || 
              e2.toString().toLowerCase().contains('権限') ||
              e2.toString().toLowerCase().contains('denied')) {
            try {
              final permission = await _getPhotoPermission();
              final status = await permission.status;
              debugPrint("📱 [QRCodeDisplayPage] 権限エラー検出。権限の状態: $status");
              
              if (status.isPermanentlyDenied) {
                _setPermissionAlert("フォトライブラリへのアクセス権限が拒否されています。\n設定アプリから権限を許可してください。");
              } else {
                _setPermissionAlert("フォトライブラリへのアクセス権限が必要です。\n設定から権限を許可してください。");
              }
            } catch (e3) {
              _setAlert("エラー", "QRコード画像の保存に失敗しました: $e2");
            }
          } else {
            _setAlert("エラー", "QRコード画像の保存に失敗しました: $e2");
          }
        }
      } finally {
        // 一時ファイルをクリーンアップ
        if (tempFilePath.isNotEmpty) {
          try {
            final file = File(tempFilePath);
            if (await file.exists()) {
              await file.delete();
              debugPrint("📱 [QRCodeDisplayPage] 一時ファイルを削除: $tempFilePath");
            }
          } catch (e) {
            debugPrint("⚠️ [QRCodeDisplayPage] 一時ファイルの削除中にエラー: $e");
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint("QRコード保存例外: $e");
      debugPrint("スタックトレース: $stackTrace");
      _setAlert("エラー", "QRコード画像の生成または保存に失敗しました: $e");
    }
  }

  void _setAlert(String title, String message) {
    if (mounted) {
      setState(() {
        _saveAlertMessage = "$title\n$message";
        _showSaveAlert = true;
        _needsPermission = false;
      });
    }
  }

  void _setPermissionAlert(String message) {
    if (mounted) {
      // プラットフォーム別の詳細な案内を追加
      String platformGuide = "";
      if (Platform.isIOS) {
        platformGuide = "\n\n【手順】\n1. 設定アプリが開きます\n2. 「脱出くん2」をタップ\n3. 「写真」をタップ\n4. 「すべての写真へのアクセスを許可」または「選択した写真へのアクセスを許可」を選択";
      } else if (Platform.isAndroid) {
        platformGuide = "\n\n【手順】\n1. 設定アプリが開きます\n2. 「アプリ」または「アプリと通知」をタップ\n3. 「脱出くん2」をタップ\n4. 「権限」をタップ\n5. 「写真とメディア」をタップ\n6. 「許可」を選択";
      }
      
      setState(() {
        _saveAlertMessage = message + platformGuide;
        _showSaveAlert = true;
        _needsPermission = true;
      });
    }
  }

  Future<void> _openAppSettings() async {
    try {
      debugPrint("📱 [QRCodeDisplayPage] 設定アプリを開きます...");
      
      // プラットフォーム別の設定ページへの直接遷移を試みる
      bool opened = false;
      
      if (Platform.isIOS) {
        // iOS: openAppSettings() がアプリの設定ページに直接遷移する
        opened = await openAppSettings();
      } else if (Platform.isAndroid) {
        // Android: openAppSettings() がアプリの設定ページに直接遷移する
        opened = await openAppSettings();
      }
      
      debugPrint("📱 [QRCodeDisplayPage] 設定アプリを開いた結果: $opened");
      
      if (!opened) {
        // 設定アプリを開けなかった場合
        if (mounted) {
          String manualGuide = "";
          if (Platform.isIOS) {
            manualGuide = "\n\n手動で開く場合:\n設定 > 脱出くん2 > 写真";
          } else if (Platform.isAndroid) {
            manualGuide = "\n\n手動で開く場合:\n設定 > アプリ > 脱出くん2 > 権限 > 写真とメディア";
          }
          _setAlert(
            "設定を開けませんでした",
            "手動で設定アプリを開き、このアプリの権限を許可してください。$manualGuide"
          );
        }
        return;
      }
      
      // 設定アプリを開いた後、アラートは閉じるが、_needsPermissionフラグは保持
      // （アプリに戻ってきたときに権限を再チェックするため）
      if (mounted) {
        setState(() {
          _showSaveAlert = false;
          // _needsPermissionはtrueのまま保持（アプリに戻ってきたときにチェックするため）
        });
      }
    } catch (e) {
      debugPrint("❌ [QRCodeDisplayPage] 設定アプリを開く際にエラー: $e");
      if (mounted) {
        String manualGuide = "";
        if (Platform.isIOS) {
          manualGuide = "\n\n手動で開く場合:\n設定 > 脱出くん2 > 写真";
        } else if (Platform.isAndroid) {
          manualGuide = "\n\n手動で開く場合:\n設定 > アプリ > 脱出くん2 > 権限 > 写真とメディア";
        }
        _setAlert(
          "エラー",
          "設定アプリを開くことができませんでした。\n手動で設定アプリを開き、このアプリの権限を許可してください。$manualGuide"
        );
      }
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black.withOpacity(0.1))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                _needsPermission ? Icons.warning_amber_rounded : Icons.check_circle,
                color: _needsPermission ? Colors.orange : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _needsPermission ? "権限が必要です" : "保存",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _saveAlertMessage,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          if (_needsPermission) ...[
            ElevatedButton.icon(
              icon: const Icon(Icons.settings, color: Colors.white),
              label: const Text(
                "設定を開く",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _openAppSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "※ 設定を変更した後、このアプリに戻ってください。\n自動的に権限を確認します。",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _showSaveAlert = false;
                  _needsPermission = false;
                });
              },
              child: const Text("後で設定する"),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showSaveAlert = false;
                  _needsPermission = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                "OK",
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}