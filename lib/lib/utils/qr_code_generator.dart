// lib/utils/qr_code_generator.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart'; // UUIDオブジェクトの利用
import 'package:intl/intl.dart'; // 日付フォーマットの利用 (ISO8601DateFormatterの代替)

/// QRコードに埋め込むデータ（文字列）の生成を管理するユーティリティクラス
class QRCodeGenerator {
  
  // Swiftの generateQRCode は、前の回答で実装した QRCodeDisplayPage 内の
  // QrImageView (qr_flutterパッケージ) が代行するため、ここでは実装しません。

  /// イベント情報からQRコードデータ文字列を生成
  /// - Parameters:
  ///   - eventName: イベント名 (Swiftの event.name に相当)
  ///   - eventDate: 開催日 (Date? に相当)
  ///   - eventId: イベントID (UUID に相当)
  /// - Returns: QRコードデータ文字列 (JSON形式を推奨)
  static String generateQRCodeData({
    required String eventName,
    required DateTime? eventDate,
    required String eventId, // DartではString (UUID.v4()の結果) で渡すことが多い
  }) {
    // Swiftの ISO8601DateFormatter の代替として、ISO 8601形式でフォーマット
    final dateString = eventDate != null
        ? DateFormat("yyyy-MM-ddTHH:mm:ss.SSSZ").format(eventDate.toUtc())
        : "";

    // QRコードデータ: イベントID、イベント名、開催日をJSON形式でエンコード (JSONSerialization.dataの代替)
    final qrData = {
      "eventId": eventId,
      "eventName": eventName,
      "eventDate": dateString
    };

    try {
      // JSONエンコード
      final jsonString = jsonEncode(qrData);
      return jsonString;
    } catch (e) {
      // JSON変換に失敗した場合はシンプルな形式で返す (Swiftのフォールバックロジックを再現)
      debugPrint("⚠️ JSONエンコード失敗: $e");
      return "$eventId|$eventName|$dateString";
    }
  }
}

// --------------------------------------------------------------------------
// 💡 QRCodeGeneratorの利用方法
// --------------------------------------------------------------------------
/*
// ProblemManagementPage での利用例:

// 1. データの生成
final String eventId = _currentEvent.id; // Event IDを取得
final qrCodeData = QRCodeGenerator.generateQRCodeData(
    eventName: _currentEvent.title,
    eventDate: _currentEvent.eventDate, // EventモデルにeventDateがある場合
    eventId: eventId,
);

// 2. データをQRコード表示ページに渡す
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => QRCodeDisplayPage(
      qrCodeData: qrCodeData,
      eventName: _currentEvent.title,
    ),
  ),
);
*/