// Event モデル（最小限の実装）
class Event {
  final String id;
  String name;
  String? comment;
  int duration;
  DateTime? eventDate;
  bool isVisible;
  String? cardImageUrl;
  String? creationPasscode;
  DateTime? lastUpdated;
  List<Problem> problems;
  List<Record> records;
  String? overview;

  Event({
    required this.id,
    required this.name,
    this.comment,
    required this.duration,
    this.eventDate,
    this.isVisible = true,
    this.cardImageUrl,
    this.creationPasscode,
    this.lastUpdated,
    this.problems = const [],
    this.records = const [],
  });

  // レコードの中でescapeTimeが最も小さいもの（1位）を返す
  Record? get bestRecord {
    if (records.isEmpty) return null;
    records.sort((a, b) => a.escapeTime.compareTo(b.escapeTime));
    return records.first;
  }

  // JSON serialization
  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      name: json['name'] as String,
      comment: json['comment'] as String?,
      duration: json['duration'] as int,
      eventDate: json['eventDate'] != null ? DateTime.parse(json['eventDate'] as String) : null,
      isVisible: json['isVisible'] as bool? ?? true,
      cardImageUrl: json['cardImageUrl'] as String?,
      creationPasscode: json['creationPasscode'] as String?,
      lastUpdated: json['lastUpdated'] != null ? DateTime.parse(json['lastUpdated'] as String) : null,
      problems: (json['problems'] as List<dynamic>?)?.map((e) => Problem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      records: (json['records'] as List<dynamic>?)?.map((e) => Record.fromJson(e as Map<String, dynamic>)).toList() ?? [],      'overview': json['overview'] as String?,    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'comment': comment,
      'duration': duration,
      'eventDate': eventDate?.toIso8601String(),
      'isVisible': isVisible,
      'cardImageUrl': cardImageUrl,
      'creationPasscode': creationPasscode,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'problems': problems.map((e) => e.toJson()).toList(),
      'records': records.map((e) => e.toJson()).toList(),
      'overview': overview,
    };
  }
}

// Problem/Record モデル（最小限の実装）
class Problem {
  final String id;
  String title;
  String? hint;
  String? answer;

  Problem({
    required this.id,
    required this.title,
    this.hint,
    this.answer,
  });

  factory Problem.fromJson(Map<String, dynamic> json) {
    return Problem(
      id: json['id'] as String,
      title: json['title'] as String,
      hint: json['hint'] as String?,
      answer: json['answer'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'hint': hint,
      'answer': answer,
    };
  }
}

class Record {
  final double escapeTime; // TimeIntervalをdoubleとして扱う

  Record(this.escapeTime);

  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(json['escapeTime'] as double);
  }

  Map<String, dynamic> toJson() {
    return {
      'escapeTime': escapeTime,
    };
  }
}

// FirebaseService のエラー型（元のSwiftコードを参考に）
class FirebaseError implements Exception {
  final String message;
  final String? detail;

  FirebaseError(this.message, {this.detail});

  @override
  String toString() => 'FirebaseError: $message${detail != null ? ' ($detail)' : ''}';

  static const eventLimitExceeded = 'eventLimitExceeded';
  static const firebaseNotConfigured = 'firebaseNotConfigured';
  static const permissionDenied = 'permissionDenied';
}