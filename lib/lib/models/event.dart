// lib/models/event.dart
import 'package:uuid/uuid.dart';
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
    
    // 2. recordsリストのパース（省略可。今回はFirebaseから取得しない想定）
    List<EscapeRecord> parsedRecords = [];
    final recordsData = json['records'];
    if (recordsData is List) {
        // ... EscapeRecordのパースロジック
    }

    // 3. Date型の変換 (Swiftの Date() は通常、秒単位のタイムスタンプまたはISO文字列)
    DateTime? parseDate(dynamic value) {
      if (value is String) return DateTime.tryParse(value);
      if (value is num) return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt()); // 秒をミリ秒に
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
}