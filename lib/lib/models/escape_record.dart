// lib/models/escape_record.dart (TimeIntervalをdoubleで扱う)
import 'package:uuid/uuid.dart';

class EscapeRecord {
  final String id;
  final String playerName;
  final double escapeTime; // Swiftの TimeInterval に相当 (秒単位)
  final DateTime completedAt;

  EscapeRecord({
    String? id,
    required this.playerName,
    required this.escapeTime,
    DateTime? completedAt,
  })  : id = id ?? const Uuid().v4(),
        completedAt = completedAt ?? DateTime.now();

  // MARK: - Firebaseへの変換（toJson）

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playerName': playerName,
      'escapeTime': escapeTime,
      // DateTimeをFirebaseが理解できるISO 8601形式の文字列に変換
      'completedAt': completedAt.toIso8601String(),
    };
  }

  // MARK: - Firebaseからの変換（fromJson）

  factory EscapeRecord.fromJson(Map<String, dynamic> json) {
    return EscapeRecord(
      id: json['id'] as String? ?? const Uuid().v4(),
      playerName: json['playerName'] as String? ?? '',
      // Dartの num 型で受け取り、doubleに変換
      escapeTime: (json['escapeTime'] as num?)?.toDouble() ?? 0.0,
      // 文字列からDateTimeオブジェクトに変換
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
}