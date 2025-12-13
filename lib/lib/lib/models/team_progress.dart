// lib/models/team_progress.dart

// 認証ステータスを明確にするための列挙型（Enum）
enum CheckStatus { 
  notStarted,        // 未着手 (デフォルト、再撮影時など)
  waitingForCheck,   // 管理者によるチェック待ち
  approved,          // 承認済み（クリア）
  rejected           // 拒否された（再挑戦が必要）
}

class TeamProgress {
  final String teamId;
  final String eventId;
  final int currentProblemIndex;
  final CheckStatus checkStatus;
  final String? uploadedImageURL;
  final bool needsAdminCheck;

  TeamProgress({
    required this.teamId,
    required this.eventId,
    required this.currentProblemIndex,
    required this.checkStatus,
    this.uploadedImageURL,
    this.needsAdminCheck = false,
  });

  // MARK: - Firebaseからの変換（fromJson）
  
  factory TeamProgress.fromJson(Map<String, dynamic> json) {
    // Firebaseから受け取った文字列をEnumに変換するヘルパー関数
    CheckStatus statusFromString(String status) {
      switch (status) {
        case 'waitingForCheck': return CheckStatus.waitingForCheck;
        case 'approved': return CheckStatus.approved;
        case 'rejected': return CheckStatus.rejected;
        default: return CheckStatus.notStarted;
      }
    }

    // FirebaseのデータはDynamicなため、型キャストを使って安全に取り出す
    return TeamProgress(
      teamId: json['teamId'] as String? ?? '', // 値がnullだった場合のデフォルト値
      eventId: json['eventId'] as String? ?? '',
      currentProblemIndex: json['currentProblemIndex'] as int? ?? 0,
      
      // 文字列として保存されているチェックステータスをEnumに変換
      checkStatus: statusFromString(json['checkStatus'] as String? ?? 'notStarted'), 
      
      uploadedImageURL: json['uploadedImageURL'] as String?,
      needsAdminCheck: json['needsAdminCheck'] as bool? ?? false,
    );
  }

  // MARK: - Firebaseへの変換（toJson）
  
  Map<String, dynamic> toJson() {
    // EnumをFirebaseに保存する文字列に戻すヘルパー関数
    String statusToString(CheckStatus status) {
      // Enumの値をそのまま文字列として返す（例: CheckStatus.approved -> 'approved'）
      return status.toString().split('.').last; 
    }
    
    return {
      'teamId': teamId,
      'eventId': eventId,
      'currentProblemIndex': currentProblemIndex,
      'checkStatus': statusToString(checkStatus),
      'uploadedImageURL': uploadedImageURL,
      'needsAdminCheck': needsAdminCheck,
    };
  }
}