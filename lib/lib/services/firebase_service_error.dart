// firebase_service_error.dart

import 'package:firebase_core/firebase_core.dart';

class FirebaseServiceError implements Exception {
  final String message;
  final String code;

  FirebaseServiceError(this.message, {this.code = 'unknown-error'});

  @override
  String toString() => 'FirebaseServiceError: [$code] $message';

  // Realtime Databaseエラーをラップするためのファクトリコンストラクタ
  factory FirebaseServiceError.fromFirebaseDatabaseError(Object error) {
    String message;
    String code = 'database-error';
    
    // firebase_database パッケージのエラーを特定
    if (error is FirebaseException) {
      code = error.code;
      message = error.message ?? 'Firebase Database操作に失敗しました';
    } else {
      message = error.toString();
    }
    
    return FirebaseServiceError(message, code: code);
  }
}