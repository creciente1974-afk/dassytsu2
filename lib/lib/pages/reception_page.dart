// lib/pages/reception_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// QRコードスキャナーウィジェットのインポート
import 'package:mobile_scanner/mobile_scanner.dart';

// 必要なモデルとページのインポート
import '../models/event.dart'; 
import 'player_name_registration_page.dart'; // 遷移先のページ

// --------------------------------------------------------------------------
// ReceptionPage
// --------------------------------------------------------------------------

class ReceptionPage extends StatefulWidget {
  final Event event;

  const ReceptionPage({super.key, required this.event});

  @override
  State<ReceptionPage> createState() => _ReceptionPageState();
}

class _ReceptionPageState extends State<ReceptionPage> {
  // Swiftの @State 変数に対応
  String? _scannedQRCode;
  bool _isAuthenticating = false;
  String _errorMessage = "";
  bool _showError = false;
  bool _shouldNavigateToRegistration = false;
  
  // Swiftの FirebaseService は認証ロジックでは使用されていないため省略

  // MARK: - UIヘルパー

  String _formatDate(DateTime date) {
    final formatter = DateFormat.yMMMMd('ja_JP'); // DateStyle .long の代替
    return formatter.format(date);
  }

  // MARK: - ロジック

  /// QRコードデータをパース
  // Swiftの parseQRCodeData(_:) の移植
  ({String eventId, String eventName, String eventDate}) _parseQRCodeData(String qrCodeString) {
    // 1. JSON形式を試す
    try {
      final json = jsonDecode(qrCodeString) as Map<String, dynamic>;
      return (
        eventId: json["eventId"]?.toString() ?? "",
        eventName: json["eventName"]?.toString() ?? "",
        eventDate: json["eventDate"]?.toString() ?? ""
      );
    } catch (_) {
      // 2. JSONパース失敗、パイプ区切り形式を試す
      final components = qrCodeString.split("|");
      if (components.length >= 3) {
        return (
          eventId: components[0],
          eventName: components[1],
          eventDate: components[2]
        );
      }
    }
    // 3. パース失敗
    return (eventId: "", eventName: "", eventDate: "");
  }

  /// QRコードを認証
  // Swiftの authenticateQRCode(_:) の移植
  Future<void> _authenticateQRCode(String scannedCode) async {
    if (!mounted) return;
    
    setState(() {
      _isAuthenticating = true;
      _errorMessage = "";
    });

    final eventQRCodeData = widget.event.qrCodeData;

    if (eventQRCodeData == null || eventQRCodeData.isEmpty) {
      _showErrorAlert("このイベントにはQRコードが設定されていません");
      return;
    }

    // スキャンしたQRコードをパース
    final scannedData = _parseQRCodeData(scannedCode);
    // イベントに設定されているQRコードデータをパース
    final eventData = _parseQRCodeData(eventQRCodeData);
    
    // イベントIDとイベント名を比較
    if (scannedData.eventId == eventData.eventId && scannedData.eventName == eventData.eventName) {
      // 認証成功: QRコード認証状態を保存 (UserDefaultsの代替)
      final prefs = await SharedPreferences.getInstance();
      final authKey = "qrCodeAuthenticated_${widget.event.id}"; // IDはDartではString
      await prefs.setBool(authKey, true);

      if (!mounted) return;
      
      // 画面遷移
      setState(() {
        _isAuthenticating = false;
        _shouldNavigateToRegistration = true;
      });
      // 認証に成功したら、PlayerNameRegistrationPageへ遷移
      _navigateToRegistrationPage();

    } else {
      // 認証失敗
      _showErrorAlert("QRコードが一致しません。正しいQRコードを読み取ってください。");
    }
  }
  
  void _showErrorAlert(String message) {
    if (!mounted) return;
    setState(() {
      _isAuthenticating = false;
      _errorMessage = message;
      _showError = true;
    });
  }
  
  void _navigateToRegistrationPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerNameRegistrationPage(event: widget.event),
      ),
    ).then((_) {
      // 戻ってきたらフラグをリセット (NavigationStackの挙動を模倣)
      if(mounted) {
        setState(() {
          _shouldNavigateToRegistration = false;
        });
      }
    });
  }
  
  // MARK: - ビルドメソッド

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("受付"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 50), // Spacerの代替
              
              // イベント情報表示
              Column(
                children: [
                  Text(
                    widget.event.name, // Swiftの event.name に相当
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (widget.event.eventDate != null)
                    Text(
                      _formatDate(widget.event.eventDate!),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[700]),
                    ),
                ],
              ),
              
              const SizedBox(height: 50), // Spacerの代替
              
              // QRコード読み取りボタン
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner, size: 24),
                label: const Text(
                  "QRコードを読み取る",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  // QRコードスキャナーシートを表示
                  _showQRCodeScannerSheet(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 認証中インジケータ
              if (_isAuthenticating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text("認証中..."),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 50), // Spacerの代替
            ],
          ),
        ),
      ),
      // エラーアラートの表示 (Swiftの .alert に相当)
      // Swiftとは異なり、setState後に直接アラートを出す必要があるため、
      // ここではビルド時に表示されるように修正します。
      bottomSheet: _showError ? _buildErrorSheet() : null,
    );
  }
  
  // エラーメッセージをBottom Sheetで表示する
  Widget _buildErrorSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.red.withOpacity(0.3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "エラー",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const Divider(),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _showError = false;
              });
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // MARK: - QRコードスキャナーの表示

  void _showQRCodeScannerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9, // 画面の大部分を占めるシート
          padding: const EdgeInsets.only(top: 20),
          child: QRCodeScannerWidget(
            onQRCodeScanned: (qrCodeString) {
              Navigator.of(context).pop(); // スキャナーシートを閉じる
              _scannedQRCode = qrCodeString;
              _authenticateQRCode(qrCodeString); // 認証ロジックを実行
            },
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------------------
// QRコードスキャナーウィジェット (Swiftの QRCodeScannerView/ViewController の代替)
// --------------------------------------------------------------------------

class QRCodeScannerWidget extends StatefulWidget {
  final ValueChanged<String> onQRCodeScanned;

  const QRCodeScannerWidget({
    super.key,
    required this.onQRCodeScanned,
  });

  @override
  State<QRCodeScannerWidget> createState() => _QRCodeScannerWidgetState();
}

class _QRCodeScannerWidgetState extends State<QRCodeScannerWidget> {
  // MobileScannerControllerは、スキャンを制御するために使用できます
  final MobileScannerController cameraController = MobileScannerController();

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  // スキャンを停止してバイブレーション (kSystemSoundID_Vibrate の代替)
                  cameraController.stop(); 
                  HapticFeedback.vibrate(); 
                  
                  // コールバックを実行
                  widget.onQRCodeScanned(code);
                }
              }
            },
          ),
          
          // キャンセルボタン (Swiftの cancelButton に相当)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20, left: 40, right: 40),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // シートを閉じる
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.8),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text("キャンセル", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}