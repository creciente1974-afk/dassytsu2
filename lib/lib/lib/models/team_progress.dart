// lib/models/team_progress.dart (カスタムエンコード/デコードロジックを実装)

// Swiftの enum CheckStatus: String, Codable に相当
enum CheckStatus {
  waitingForCheck, // 管理者チェック待ち
  approved,        // 認証クリア
  rejected,        // 認証失敗（再撮影が必要）
  notStarted,      // まだチェックページに到達していない
}

extension CheckStatusExtension on CheckStatus {
  // Enumを文字列として扱うためのヘルパー
  String get value {
    switch (this) {
      case CheckStatus.waitingForCheck:
        return 'waitingForCheck';
      case CheckStatus.approved:
        return 'approved';
      case CheckStatus.rejected:
        return 'rejected';
      case CheckStatus.notStarted:
        return 'notStarted';
    }
  }
}

class TeamProgress {
  final String teamId;
  final String eventId;
  final int currentProblemIndex;
  CheckStatus checkStatus;
  // Swiftの uploadedImageURL (古いフィールド) に対応
  String? uploadedImageURL; 
  DateTime lastUpdated;
  int currentStage;
  // Swiftの uploaded_image_url (新しいフィールド) に対応
  String? uploadedImageUrlNew; 
  bool needsAdminCheck;

  TeamProgress({
    required this.teamId,
    required this.eventId,
    required this.currentProblemIndex,
    required this.checkStatus,
    this.uploadedImageURL,
    DateTime? lastUpdated,
    this.currentStage = 0,
    this.uploadedImageUrlNew,
    this.needsAdminCheck = false,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
  
  // MARK: - Firebaseからの変換（fromJson）

  factory TeamProgress.fromJson(Map<String, dynamic> json) {
    // CheckStatusの変換
    CheckStatus status;
    final statusString = json['checkStatus'] as String? ?? 'notStarted';
    switch (statusString) {
      case 'waitingForCheck': status = CheckStatus.waitingForCheck; break;
      case 'approved': status = CheckStatus.approved; break;
      case 'rejected': status = CheckStatus.rejected; break;
      default: status = CheckStatus.notStarted; break;
    }

    // lastUpdated のデコード (Swiftの timeIntervalSince1970 に対応)
    DateTime lastUpdatedDate = DateTime.now();
    final lastUpdatedValue = json['lastUpdated'];
    if (lastUpdatedValue is num) {
      // 秒単位のタイムスタンプをミリ秒に変換
      lastUpdatedDate = DateTime.fromMillisecondsSinceEpoch((lastUpdatedValue * 1000).toInt());
    } else if (lastUpdatedValue is String) {
      // ISO 8601文字列の場合
      lastUpdatedDate = DateTime.tryParse(lastUpdatedValue) ?? DateTime.now();
    }
    
    // Swiftのuploaded_image_url（新）とuploadedImageURL（旧）の互換性処理
    final uploadedImageUrlNew = json['uploaded_image_url'] as String?;
    final uploadedImageUrlOld = json['uploadedImageURL'] as String?;
    
    return TeamProgress(
      teamId: json['teamId'] as String? ?? '',
      eventId: json['eventId'] as String? ?? '',
      currentProblemIndex: json['currentProblemIndex'] as int? ?? 0,
      checkStatus: status,
      uploadedImageURL: uploadedImageUrlOld, // 古いフィールド
      lastUpdated: lastUpdatedDate,
      currentStage: json['current_stage'] as int? ?? 0,
      uploadedImageUrlNew: uploadedImageUrlNew ?? uploadedImageUrlOld, // 新しいフィールド（旧フィールドがあれば使用）
      needsAdminCheck: json['needs_admin_check'] as bool? ?? false,
    );
  }

  // MARK: - Firebaseへの変換（toJson）

  Map<String, dynamic> toJson() {
    return {
      'teamId': teamId,
      'eventId': eventId,
      'currentProblemIndex': currentProblemIndex,
      'checkStatus': checkStatus.value,
      // 古いフィールドも互換性のために送信
      'uploadedImageURL': uploadedImageURL, 
      // Swift互換のために timeIntervalSince1970 (秒) で保存
      'lastUpdated': lastUpdated.millisecondsSinceEpoch / 1000.0, 
      'current_stage': currentStage,
      // 新しいフィールド
      'uploaded_image_url': uploadedImageUrlNew ?? uploadedImageURL, 
      'needs_admin_check': needsAdminCheck,
    };
  }
}