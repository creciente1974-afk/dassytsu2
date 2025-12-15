// lib/models/event.dart
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'problem.dart';
import 'escape_record.dart';

class Event {
  final String id;
  final String name;
  final List<Problem> problems;
  final int duration; // 制限時間 (分)
  final List<EscapeRecord> records; // 脱出記録 (アプリ内では不要だが、FireStoreとの互換性のため保持)
  final String? targetObjectText;
  final String? targetObjectImageUrl;
  final String? cardImageUrl;
  final String? creationPasscode;
  final DateTime? eventDate;
  final bool isVisible;
  final DateTime? lastUpdated;
  final String? comment;
  final String? overview;
  final String? qrCodeData;

  Event({
    String? id,
    required this.name,
    this.problems = const [],
    required this.duration,
    this.records = const [],
    this.targetObjectText,
    this.targetObjectImageUrl,
    this.cardImageUrl,
    this.creationPasscode,
    this.eventDate,
    this.isVisible = true,
    DateTime? lastUpdated,
    this.comment,
    this.overview,
    this.qrCodeData,
  })  : id = id ?? const Uuid().v4(),
        lastUpdated = lastUpdated ?? DateTime.now();

  // MARK: - Firebaseからの変換（fromJson）

  factory Event.fromJson(Map<String, dynamic> json) {
    // 1. problemsリストのパース
    List<Problem> parsedProblems = [];
    final problemsData = json['problems'];
    
    if (problemsData is List) {
      parsedProblems = (problemsData as List)
          .map((item) => Problem.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } else if (problemsData is Map) {
      // Firebase Realtime Databaseで配列がMapとして扱われる場合に対応
      final problemsMap = Map<String, dynamic>.from(problemsData);
      
      // キー（インデックス）に基づいてソートしてリスト化
      final sortedValues = problemsMap.keys.toList()
          ..sort((a, b) {
            // キーが文字列化されたインデックス ("0", "1", "2") の場合に対応
            final aInt = int.tryParse(a) ?? -1;
            final bInt = int.tryParse(b) ?? -1;
            return aInt.compareTo(bInt);
          });
      
      for (var key in sortedValues) {
          final problemData = problemsMap[key];
          if (problemData != null) {
              parsedProblems.add(Problem.fromJson(Map<String, dynamic>.from(problemData as Map)));
          }
      }
    }
    
    // 2. recordsリストのパース
    List<EscapeRecord> parsedRecords = [];
    final recordsData = json['records'];
    if (recordsData is List) {
      parsedRecords = recordsData
          .map((item) {
            try {
              if (item is Map) {
                return EscapeRecord.fromJson(Map<String, dynamic>.from(item));
              }
              return null;
            } catch (e) {
              debugPrint("⚠️ [Event.fromJson] EscapeRecordパースエラー: $e");
              return null;
            }
          })
          .whereType<EscapeRecord>()
          .toList();
    } else if (recordsData is Map) {
      // Firebase Realtime Databaseで配列がMapとして扱われる場合に対応
      final recordsMap = Map<String, dynamic>.from(recordsData);
      recordsMap.forEach((key, value) {
        try {
          if (value is Map) {
            final recordMap = Map<String, dynamic>.from(value);
            recordMap['id'] = key; // キーをIDとして使用
            parsedRecords.add(EscapeRecord.fromJson(recordMap));
          }
        } catch (e) {
          debugPrint("⚠️ [Event.fromJson] EscapeRecordパースエラー (key: $key): $e");
        }
      });
    }

    // 3. Date型の変換 (FirebaseからはISO8601文字列またはミリ秒/秒の数値で来る可能性がある)
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        // ISO8601文字列としてパース
        return DateTime.tryParse(value);
      }
      if (value is num) {
        final numValue = value.toInt();
        // ミリ秒か秒かを判定（一般的に1000000000000より小さい場合は秒単位とみなす）
        if (numValue > 1000000000000) {
          // ミリ秒単位
          return DateTime.fromMillisecondsSinceEpoch(numValue);
        } else {
          // 秒単位
          return DateTime.fromMillisecondsSinceEpoch(numValue * 1000);
        }
      }
      return null;
    }

    return Event(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '名称未設定イベント',
      problems: parsedProblems,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      records: parsedRecords,
      targetObjectText: json['target_object_text'] as String?,
      targetObjectImageUrl: json['target_object_image_url'] as String?,
      cardImageUrl: json['card_image_url'] as String?,
      creationPasscode: json['creation_passcode'] as String?,
      eventDate: parseDate(json['eventDate']),
      isVisible: json['isVisible'] as bool? ?? true,
      lastUpdated: parseDate(json['lastUpdated']),
      comment: json['comment'] as String?,
      overview: json['overview'] as String?,
      qrCodeData: json['qrCodeData'] as String?,
    );
  }

  // MARK: - Firebaseへの変換（toJson）
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'problems': problems.map((p) => p.toJson()).toList(),
      'duration': duration,
      'records': records.map((r) => r.toJson()).toList(),
      'target_object_text': targetObjectText,
      'target_object_image_url': targetObjectImageUrl,
      'card_image_url': cardImageUrl,
      'creation_passcode': creationPasscode,
      // DateTimeをFirebase互換のISO 8601文字列に変換
      'eventDate': eventDate?.toIso8601String(),
      'isVisible': isVisible,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'comment': comment,
      'overview': overview,
      'qrCodeData': qrCodeData,
    };
  }

  // copyWithメソッドを追加
  Event copyWith({
    String? id,
    String? name,
    List<Problem>? problems,
    int? duration,
    List<EscapeRecord>? records,
    String? targetObjectText,
    String? targetObjectImageUrl,
    String? cardImageUrl,
    String? creationPasscode,
    DateTime? eventDate,
    bool? isVisible,
    DateTime? lastUpdated,
    String? comment,
    String? overview,
    String? qrCodeData,
  }) {
    return Event(
      id: id ?? this.id,
      name: name ?? this.name,
      problems: problems ?? this.problems,
      duration: duration ?? this.duration,
      records: records ?? this.records,
      targetObjectText: targetObjectText ?? this.targetObjectText,
      targetObjectImageUrl: targetObjectImageUrl ?? this.targetObjectImageUrl,
      cardImageUrl: cardImageUrl ?? this.cardImageUrl,
      creationPasscode: creationPasscode ?? this.creationPasscode,
      eventDate: eventDate ?? this.eventDate,
      isVisible: isVisible ?? this.isVisible,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      comment: comment ?? this.comment,
      overview: overview ?? this.overview,
      qrCodeData: qrCodeData ?? this.qrCodeData,
    );
  }
}