// lib/models/problem.dart (全体をこの内容で上書きしてください)
import 'package:uuid/uuid.dart';
import 'hint.dart'; // 新しく定義したHintモデルをインポート

const Uuid _uuid = Uuid(); // 💡 Uuidのインスタンスを定数として定義
class Problem {
  final String id;
  final String? text;
  final String mediaURL; // Firebase StorageのURL
  final String answer;
  final List<Hint> hints;
  final String? checkText;
  final String? checkImageURL;
  final bool requiresCheck;

  Problem({
    String? id,
    this.text,
    required this.mediaURL,
    required this.answer,
    required this.hints,
    this.checkText,
    this.checkImageURL,
    required this.requiresCheck,
  }) : id = id ?? _uuid.v4(); // 👈 修正後: 先頭で定義した定数を使用
  
  // MARK: - Firebaseからの変換（fromJson）

  factory Problem.fromJson(Map<String, dynamic> json) {
    // hintsリストのパース処理
    List<Hint> parsedHints = [];
    final hintsData = json['hints'];
    
    if (hintsData is List) {
      parsedHints = (hintsData as List)
          .map((item) => Hint.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    } else if (hintsData is Map) {
      // Realtime Databaseで配列がMapとして扱われる場合の対応
      final hintsMap = Map<String, dynamic>.from(hintsData);
      parsedHints = hintsMap.values
          .map((item) => Hint.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return Problem(
      id: json['id'] as String? ?? const Uuid().v4(),
      text: json['text'] as String?,
      mediaURL: json['mediaURL'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      hints: parsedHints,
      checkText: json['checkText'] as String?,
      checkImageURL: json['checkImageURL'] as String?,
      // Swiftではデフォルトがtrueですが、Firebaseでは明示的な値が推奨されます
      requiresCheck: json['requiresCheck'] as bool? ?? true, 
    );
  }

  // MARK: - Firebaseへの変換（toJson）

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'mediaURL': mediaURL,
      'answer': answer,
      'hints': hints.map((h) => h.toJson()).toList(),
      'checkText': checkText,
      'checkImageURL': checkImageURL,
      'requiresCheck': requiresCheck,
    };
  }
}