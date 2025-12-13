// event_list_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'dart:math';

// --- 仮定されるデータモデルとサービス ---
// 実際のプロジェクトに合わせて調整してください。

class Event {
  final String id;
  final String name;
  final DateTime? eventDate; // 開催日時
  final DateTime? lastUpdated; // 最終更新日時
  final bool isVisible; // 公開設定
  final double duration; // 制限時間（TimeIntervalの代わり）

  Event({
    required this.id,
    required this.name,
    this.eventDate,
    this.lastUpdated,
    this.isVisible = true,
    this.duration = 60.0,
  });
}

// FirebaseService の仮定
class FirebaseService {
  static final FirebaseService shared = FirebaseService._internal();
  FirebaseService._internal();

  Future<List<Event>> getAllEvents() async {
    // 実際はFirebase Firestoreからイベントを取得
    await Future.delayed(const Duration(seconds: 2)); // 読み込みのシミュレーション
    
    // サンプルデータ
    return [
      Event(
        id: '1',
        name: '謎解きイベントA',
        eventDate: DateTime.now().add(const Duration(days: 5)),
        lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
        isVisible: true,
      ),
      Event(
        id: '2',
        name: '過去のイベント',
        eventDate: DateTime.now().subtract(const Duration(days: 10)),
        lastUpdated: DateTime.now().subtract(const Duration(days: 2)),
        isVisible: true,
      ),
      Event(
        id: '3',
        name: '非公開イベント',
        eventDate: DateTime.now().add(const Duration(days: 1)),
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 30)),
        isVisible: false,
      ),
      Event(
        id: '4',
        name: '本日のイベント',
        eventDate: DateTime.now().subtract(const Duration(hours: 2)), // 同日判定のテスト用
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 10)),
        isVisible: true,
      ),
      Event(
        id: '5',
        name: '本日のイベント (古い更新)',
        eventDate: DateTime.now().subtract(const Duration(hours: 4)), // 同日判定のテスト用
        lastUpdated: DateTime.now().subtract(const Duration(minutes: 60)),
        isVisible: true,
      ),
    ];
  }
}

// EventCardView (ダミー)
class EventCardView extends StatelessWidget {
  final Event event;
  const EventCardView({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        title: Text(event.name),
        subtitle: Text('開催日: ${EventListPageState.formatDate(event.eventDate ?? DateTime.now())}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // イベント詳細画面への遷移ロジックをここに実装
          print('${event.name} がタップされました');
        },
      ),
    );
  }
}

// PasswordInputView, AdminView (ダミー)
class PasswordInputPage extends StatelessWidget {
  final Function(bool) onPasswordVerified;
  const PasswordInputPage({super.key, required this.onPasswordVerified});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パスワード入力')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            onPasswordVerified(true); // 認証成功と仮定
            Navigator.pop(context); // シートを閉じる
          },
          child: const Text('管理者認証 (ダミー)'),
        ),
      ),
    );
  }
}

class AdminPage extends StatelessWidget {
  final List<Event> events;
  final VoidCallback onSave;
  const AdminPage({super.key, required this.events, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理者ページ')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            onSave(); // イベントリストの更新をトリガー
            Navigator.pop(context); // シートを閉じる
          },
          child: const Text('イベントを更新して閉じる (ダミー)'),
        ),
      ),
    );
  }
}
// ------------------------------------


class EventListPage extends StatefulWidget {
  const EventListPage({super.key});

  @override
  State<EventListPage> createState() => EventListPageState();
}

class EventListPageState extends State<EventListPage> {
  List<Event> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showError = false;

  final FirebaseService _firebaseService = FirebaseService.shared;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }
  
  // SwiftUIの sortedEvents に相当するGetter
  List<Event> get _sortedEvents {
    final visibleEvents = _events.where((e) => e.isVisible).toList();

    visibleEvents.sort((event1, event2) {
      final date1 = event1.eventDate ?? DateTime(9999, 12, 31);
      final date2 = event2.eventDate ?? DateTime(9999, 12, 31);

      // 1. 同じ日の場合（日付のみで比較）
      if (isSameDay(date1, date2)) {
        // 更新順（最新の更新が先）
        final updated1 = event1.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
        final updated2 = event2.lastUpdated ?? DateTime.fromMillisecondsSinceEpoch(0);
        return updated2.compareTo(updated1); // 降順
      }

      // 2. 開催日時の近い順（未来の日付が先）
      return date1.compareTo(date2); // 昇順
    });

    return visibleEvents;
  }

  // 日付のみで比較するヘルパー関数
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  // SwiftUIの loadEvents() に相当
  Future<void> _loadEvents() async {
    if (_isLoading) return; // 既にロード中の場合はスキップ

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print("🔄 [EventListPage] イベント読み込み開始");

    try {
      print("📡 [EventListPage] Firebaseからイベントを取得中...");
      final loadedEvents = await _firebaseService.getAllEvents();
      print("✅ [EventListPage] イベント取得成功: ${loadedEvents.length}件");

      if (mounted) {
        setState(() {
          _events = loadedEvents;
          _isLoading = false;
          print("✅ [EventListPage] UI更新完了: ${_events.length}件のイベントを表示");
        });
      }
    } catch (error) {
      print("❌ [EventListPage] エラー発生: ${error.toString()}");
      if (mounted) {
        setState(() {
          _errorMessage = error.toString(); // DartのlocalizedDescriptionは存在しないため、toString()を使用
          _showError = true;
          _isLoading = false;
        });
      }
    }
  }

  // SwiftUIの formatDate(_:) に相当
  static String formatDate(DateTime date) {
    final formatter = DateFormat.yMMMd('ja'); // 'yMMMd' は Mediumスタイルに近い
    return formatter.format(date);
  }

  // SwiftUIの formatTime(_:) に相当
  static String formatTime(double timeInterval) {
    final minutes = timeInterval ~/ 60; // 整数除算
    final seconds = (timeInterval % 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ナビゲーションを扱うため、WidgetTree全体をBuilderでラップします。
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("イベント一覧"),
        automaticallyImplyLeading: false,
        actions: [
          // 更新ボタン (ToolbarItem(placement: .navigationBarLeading))
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadEvents, // ロード中は無効
          ),
          // 管理者ボタン (ToolbarItem(placement: .navigationBarTrailing))
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: _showPasswordInputSheet,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          return RefreshIndicator( // .refreshable の代わり
            onRefresh: _loadEvents,
            child: Container(
              color: Colors.grey.shade100, // Color(.systemGroupedBackground) の代わり
              child: _buildBodyContent(context),
            ),
          );
        },
      ),
    );
  }

  // メインコンテンツの条件分岐 (isLoading, events.isEmpty, List)
  Widget _buildBodyContent(BuildContext context) {
    if (_isLoading) {
      // isLoading
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator.adaptive(),
            SizedBox(height: 16),
            Text("イベントを読み込み中..."),
          ],
        ),
      );
    } else if (_events.isEmpty) {
      // events.isEmpty
      return Center(
        child: SingleChildScrollView( // Pull to refresh が使えるようにSingleChildScrollViewでラップ
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.calendar_month_outlined, // calendar.badge.exclamationmark に近いアイコン
                  size: 60,
                  color: Colors.grey,
                ),
                const SizedBox(height: 20),
                const Text(
                  "イベントがありません",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "管理者ページからイベントを作成してください",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // イベントリスト
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _sortedEvents.length,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final event = _sortedEvents[index];
          return EventCardView(event: event);
        },
      );
    }
  }

  // パスワード入力シートの表示 (sheet(isPresented: $showPasswordInput))
  void _showPasswordInputSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return PasswordInputPage(
          onPasswordVerified: (isVerified) {
            if (isVerified) {
              _showAdminSheet();
            }
          },
        );
      },
    );
  }

  // 管理者画面シートの表示 (sheet(isPresented: $showAdminView))
  void _showAdminSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return AdminPage(
          events: _events, // AdminViewにイベントを渡す
          onSave: _loadEvents, // 保存後にリストを再読み込み
        );
      },
    );
  }
}