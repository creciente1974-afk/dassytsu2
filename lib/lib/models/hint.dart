// lib/models/hint.dart
import 'package:uuid/uuid.dart';

class Hint {
  // Swiftの UUID に相当。Stringで扱う
  final String id; 
  final String content;
  // ヒントが開示される時間オフセット（秒）
  final int timeOffset; 

  Hint({
    String? id,
    required this.content,
    required this.timeOffset,
  }) : id = id ?? const Uuid().v4();
  
  // MARK: - Firebaseとの相互変換

  factory Hint.fromJson(Map<String, dynamic> json) {
    return Hint(
      id: json['id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      timeOffset: json['timeOffset'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'timeOffset': timeOffset,
    };
  }
}