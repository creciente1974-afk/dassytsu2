// --------------------------------------------------------------------------
// MARK: - Data Models
// --------------------------------------------------------------------------

import 'package:flutter/foundation.dart';
class Problem {
  final String id;
  final String text;
  final String? mediaURL;
  final String answer;
  // 他のフィールドは省略...
  final List<dynamic> hints; // ヒントモデルは今回は省略
  final bool requiresCheck;
  final String? checkText;
  final String? checkImageURL;

  Problem({
    required this.id,
    required this.text,
    this.mediaURL,
    required this.answer,
    this.hints = const [],
    this.requiresCheck = false,
    this.checkText,
    this.checkImageURL,
  });

  factory Problem.fromJson(Map<String, dynamic> json) {
    return Problem(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      mediaURL: json['mediaURL'] as String?,
      answer: json['answer'] as String? ?? '',
      hints: json['hints'] as List<dynamic>? ?? [],
      requiresCheck: json['requiresCheck'] as bool? ?? false,
      checkText: json['checkText'] as String?,
      checkImageURL: json['checkImageURL'] as String?,
    );
  }
}

class EscapeRecord {
  final String id;
  final String playerName;
  final double escapeTime; // TimeInterval は Dart では double (秒単位)
  final DateTime completedAt;

  EscapeRecord({
    required this.id,
    required this.playerName,
    required this.escapeTime,
    required this.completedAt,
  });
  
  // Realtime Databaseから取得したレコードをパース
  factory EscapeRecord.fromJson(Map<String, dynamic> json) {
    return EscapeRecord(
      id: json['id'] as String? ?? '',
      playerName: json['playerName'] as String? ?? '匿名',
      // Firebaseでは数値は int/double で取得される
      escapeTime: (json['escapeTime'] as num?)?.toDouble() ?? 0.0,
      // DateはFirebaseからUnixミリ秒(int)またはISO8601文字列で来ることを想定
      completedAt: DateTime.fromMillisecondsSinceEpoch(json['completedAt'] as int? ?? 0),
    );
  }
}


class Event {
  final String id;
  final String name;
  final List<Problem> problems;
  final int duration;
  final List<EscapeRecord> records;
  final String? card_image_url;
  final String? overview; // 新しく追加
  final DateTime? eventDate; // 新しく追加
  final bool isVisible;
  final String? qrCodeData; // QRコードデータ
  // その他のフィールドは省略...

  Event({
    required this.id,
    required this.name,
    this.problems = const [],
    required this.duration,
    this.records = const [],
    this.card_image_url,
    this.overview,
    this.eventDate,
    this.isVisible = true,
    this.qrCodeData,
  });

  // Realtime Databaseからのパースロジック (簡略化)
  factory Event.fromJson(Map<String, dynamic> json) {
    // problems
    final problemsData = json['problems'] as List<dynamic>? ?? [];
    final parsedProblems = problemsData
        .map((p) => Problem.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList();

    // records (FirebaseからMapまたはListとして来る可能性があるため処理を調整)
    final recordsData = json['records'] as Map<dynamic, dynamic>?;
    List<EscapeRecord> parsedRecords = [];
    if (recordsData != null) {
        recordsData.forEach((key, value) {
            if (value is Map) {
                final recordMap = Map<String, dynamic>.from(value);
                // IDフィールドがない場合、キーをIDとして利用する
                recordMap['id'] = key;
                try {
                    parsedRecords.add(EscapeRecord.fromJson(recordMap));
                } catch (e) {
                    debugPrint("レコードパースエラー: $e");
                }
            }
        });
    }

    // eventDate (FirebaseからUnixミリ秒またはISO8601文字列で来ることを想定)
    DateTime? parsedDate;
    final dateValue = json['eventDate'];
    if (dateValue is int) {
        parsedDate = DateTime.fromMillisecondsSinceEpoch(dateValue);
    } 
    // ISO8601文字列対応が必要ならDateTime.tryParse(dateValue as String)を実装

    return Event(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '名称未設定',
      problems: parsedProblems,
      duration: json['duration'] as int? ?? 0,
      records: parsedRecords,
      card_image_url: json['card_image_url'] as String?,
      overview: json['overview'] as String?,
      eventDate: parsedDate,
      isVisible: json['isVisible'] as bool? ?? true,
      qrCodeData: json['qrCodeData'] as String?,
    );
  }
}