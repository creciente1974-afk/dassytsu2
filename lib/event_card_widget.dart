import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart'; // Event モデルをインポート
import 'firebase_service.dart'; // FirebaseService クラスをインポート

// ⚠️ 注意: ReceptionViewは別途定義が必要です。

class EventCard extends StatefulWidget {
  final Event event;
  
  // 画面遷移用のコールバック（通常は親画面で定義し、Navigator.pushを呼び出す）
  final VoidCallback onTapped; 

  const EventCard({
    super.key,
    required this.event,
    required this.onTapped,
  });

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  // @State private var challengeCount: Int = 0
  int _challengeCount = 0;
  // @State private var rankingPosition: Int? = nil
  int? _rankingPosition;
  
  // private let firebaseService = FirebaseService.shared に相当
  // final FirebaseService _firebaseService = FirebaseService(); 

  @override
  void initState() {
    super.initState();
    // .onAppear { loadUserStats() } に相当
    _loadUserStats();
  }
  
  // MARK: - Utility Methods

  // private func formatTime(_ timeInterval: TimeInterval) に相当
  String _formatTime(double timeInterval) {
    final minutes = (timeInterval ~/ 60).toString();
    final seconds = (timeInterval % 60).toStringAsFixed(0).padLeft(2, '0');
    return "${minutes}:${seconds}";
  }

  // private func formatDate(_ date: Date) に相当
  String _formatDate(DateTime date) {
    // intlパッケージを使用 (SwiftのDateFormatter.dateStyle = .medium に近い)
    final formatter = DateFormat.yMMMd('ja_JP');
    return formatter.format(date);
  }
  
  // MARK: - Data Loading

  // private func loadUserStats() に相当
  Future<void> _loadUserStats() async {
    final prefs = await SharedPreferences.getInstance();
    final eventId = widget.event.id;
    
    // プレイヤー名が登録されているか確認
    final playerNameKey = "playerName_$eventId";
    if (prefs.getString(playerNameKey) == null) {
      return;
    }
    
// setState(() {
      //   _isLoadingStats = true;
      // });
    
    try {
      // ⚠️ FlutterではデバイスIDの取得は 'device_info_plus' パッケージなどが一般的ですが、
      // ここではSwiftのUIDevice.current.identifierForVendorに相当する
      // 永続的なIDをSharedPreferencesから取得/生成する簡易ロジックを採用します。
      // (前回回答のIndividualEventScreenで定義した_generateTeamIdと似たロジック)
      // final deviceId = prefs.getString("deviceId") ?? "default_device_id"; 
      
      // 挑戦回数とランキング順位を並列で取得
      // FirebaseServiceには、getChallengeCountとgetRankingPositionの実装が必要です。
      // final count = await _firebaseService.getChallengeCount(deviceId: deviceId, eventId: eventId);
      // final rank = await _firebaseService.getRankingPosition(deviceId: deviceId, eventId: eventId);
      final count = 0; // 仮
      final rank = 0; // 仮
      
      if (mounted) {
        setState(() {
          _challengeCount = count;
          _rankingPosition = rank;
          // _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("⚠️ [EventCard] 統計情報の取得に失敗: $e");
      if (mounted) {
        setState(() {
          // _isLoadingStats = false;
        });
      }
    }
  }

  // MARK: - Component Builders
  
  // 脱出ランキング1位のタイム表示部分
  Widget _buildBestRecordBadge() {
    // event.records.sorted(by: { $0.escapeTime < $1.escapeTime }).first に相当
    final bestRecord = widget.event.records.isNotEmpty 
        ? widget.event.records.reduce((a, b) => a.escapeTime < b.escapeTime ? a : b)
        : null;

    if (bestRecord == null) {
      return const SizedBox.shrink(); // レコードがない場合は非表示
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🥇 1位",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              _formatTime(bestRecord.escapeTime),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 画像表示エリア
  Widget _buildImageArea(BuildContext context) {
    // GeometryReader + frame(height: 120) に相当
    const double imageHeight = 120.0; 
    
    // 画像URLがない場合の代替イメージ
    Widget defaultImage = Container(
      width: double.infinity,
      height: imageHeight,
      color: Colors.grey[300],
      alignment: Alignment.center,
      // Swiftの Image("noimage") に相当するPlaceholder
      child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
    );

    Widget imageWidget;
    final imageUrl = widget.event.card_image_url;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      // AsyncImage / cached_network_image に相当
      imageWidget = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover, // .aspectRatio(contentMode: .fill)
        width: double.infinity,
        height: imageHeight,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
        errorWidget: (context, url, error) => defaultImage,
      );
    } else {
      imageWidget = defaultImage;
    }
    
    // ZStack(alignment: .topLeading) に相当
    return SizedBox(
      height: imageHeight,
      child: Stack(
        children: [
          // 画像本体
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: imageWidget,
          ),
          // 脱出ランキング1位のタイム表示
          Align(
            alignment: Alignment.topLeft,
            child: _buildBestRecordBadge(),
          ),
        ],
      ),
    );
  }

  // コンテンツエリア
  Widget _buildContentArea(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // イベント名
          Text(
            widget.event.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // イベント日時
          if (widget.event.eventDate != null)
            Text(
              _formatDate(widget.event.eventDate!),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Colors.grey, // .secondary
              ),
            ),
          const SizedBox(height: 4),

          // コメント
          if (widget.event.comment != null && widget.event.comment!.isNotEmpty)
            Text(
              widget.event.comment!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
              ),
              maxLines: 2, // .lineLimit(2)
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 12),

          // 問題数と制限時間
          Row(
            children: [
              _buildIconText(
                "${widget.event.problems.length}問",
                Icons.list_alt,
              ),
              const SizedBox(width: 16),
              _buildIconText(
                "${widget.event.duration}分",
                Icons.access_time,
              ),
              const Spacer(), // Spacer() に相当
              const Icon(
                Icons.chevron_right, // chevron.right
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
          
          // ユーザーの挑戦回数とランキング順位を表示
          if (_challengeCount > 0 || _rankingPosition != null)
            Column(
              children: [
                const Divider(height: 20, thickness: 1), // Divider().padding(.vertical, 4)
                Row(
                  children: [
                    if (_challengeCount > 0)
                      _buildUserStat(
                        "挑戦回数: $_challengeCount回",
                        Icons.cached,
                        Colors.blue,
                      ),
                    const SizedBox(width: 16),
                    if (_rankingPosition != null)
                      _buildUserStat(
                        "ランキング: $_rankingPosition位",
                        Icons.emoji_events,
                        Colors.orange,
                      ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  // Icon + Text (問題数/時間)
  Widget _buildIconText(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  // ユーザーの統計情報 (挑戦回数/ランキング)
  Widget _buildUserStat(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // MARK: - Main Build

  @override
  Widget build(BuildContext context) {
    // NavigationLink に相当
    return GestureDetector(
      onTap: widget.onTapped,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Card( // .background().cornerRadius().shadow() に相当
          elevation: 4, // 影
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // VStack(alignment: .leading, spacing: 0) に相当
            children: [
              // 画像エリア
              _buildImageArea(context),
              
              // コンテンツエリア
              _buildContentArea(context),
            ],
          ),
        ),
      ),
    );
  }
}

// MARK: - 使用例 (親ウィジェットでの利用)

/*
// Parent Screen Example
class EventListScreen extends StatelessWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ダミーデータ
    final dummyEvent = Event(
      id: "event_123",
      name: "伝説の地下迷宮からの脱出",
      problems: List.generate(5, (index) => Problem(id: index.toString(), text: "P$index", answer: "A$index")),
      duration: 60,
      card_image_url: "https://example.com/some_image.jpg", // 適切なURLに置き換えてください
      eventDate: DateTime.now().add(const Duration(days: 30)),
      comment: "史上最高の難易度！クリアできるかな？",
      records: [
          EscapeRecord(id: "r1", playerName: "Alpha", escapeTime: 1234.0, completedAt: DateTime.now()),
          EscapeRecord(id: "r2", playerName: "Bravo", escapeTime: 987.0, completedAt: DateTime.now()),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('イベント一覧')),
      body: ListView(
        children: [
          EventCard(
            event: dummyEvent,
            onTapped: () {
              // NavigationLink(destination: ReceptionView(event: event)) に相当
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) => ReceptionView(event: dummyEvent), // ⚠️ ReceptionViewをインポート
              ));
            },
          ),
          // 他のイベントカード...
        ],
      ),
    );
  }
}
*/