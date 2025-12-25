// event_list_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'lib/models/event.dart' as lib_models; // 正規のEventモデル
import 'lib/models/escape_record.dart' as lib_models; // EscapeRecordモデル
import 'event_model.dart' as event_model; // IndividualEventScreen用のEventモデル
import 'firebase_service.dart'; // FirebaseService
import 'event_title_edit_view.dart'; // EventTitleEditView
import 'individual_event_screen.dart'; // IndividualEventScreen
import 'lib/pages/problem_management_page.dart'; // ProblemManagementPage
import 'lib/pages/player_name_registration_page.dart'; // PlayerNameRegistrationPage
import 'lib/pages/player_name_edit_page.dart'; // PlayerNameEditPage
import 'lib/pages/reception_page.dart'; // ReceptionPage
import 'lib/pages/clear_page.dart'; // ClearPage
import 'pages/subscription_page.dart'; // SubscriptionPage
import 'services/revenuecat_service.dart'; // RevenueCatService

// lib_models.Event を event_model.Event に変換するヘルパー関数
event_model.Event _convertEvent(lib_models.Event libEvent) {
  return event_model.Event(
    id: libEvent.id,
    name: libEvent.name,
    problems: libEvent.problems.map((p) => event_model.Problem(
      id: p.id,
      text: p.text ?? '',
      mediaURL: p.mediaURL,
      answer: p.answer,
      hints: p.hints.map((h) => h.toString()).toList(), // Hintをdynamicに変換
    )).toList(),
    duration: libEvent.duration,
    records: libEvent.records.map((r) => event_model.EscapeRecord(
      id: r.id,
      playerName: r.playerName,
      escapeTime: r.escapeTime,
      completedAt: r.completedAt,
    )).toList(),
    card_image_url: libEvent.cardImageUrl,
    overview: libEvent.overview,
    eventDate: libEvent.eventDate,
    isVisible: libEvent.isVisible,
  );
}

// EventCardView
class EventCardView extends StatelessWidget {
  final lib_models.Event event;
  const EventCardView({super.key, required this.event});

  // ランキング1位のタイムを取得
  lib_models.EscapeRecord? get _bestRecord {
    if (event.records.isEmpty) return null;
    return event.records.reduce((a, b) => a.escapeTime < b.escapeTime ? a : b);
  }

  // タイムをフォーマット
  String _formatTime(double timeInterval) {
    final minutes = (timeInterval ~/ 60).toString();
    final seconds = (timeInterval % 60).toStringAsFixed(0).padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final bestRecord = _bestRecord;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ランキング1位のバッジ（画像エリアがある場合の代替表示）
          if (bestRecord != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    "🥇 1位: ${_formatTime(bestRecord.escapeTime)} (${bestRecord.playerName})",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ListTile(
            title: Text(
              event.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (event.eventDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '開催日: ${EventListPageState.formatDate(event.eventDate!)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                if (event.comment != null && event.comment!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      event.comment!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // ランキング情報を追加表示
                if (event.records.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'ランキング: ${event.records.length}件',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
          // クリア済みかどうかをチェック
          final prefs = await SharedPreferences.getInstance();
          final clearCheckedKey = "clearChecked_${event.id}";
          final isClearChecked = prefs.getBool(clearCheckedKey) ?? false;
          
          if (isClearChecked) {
            // クリア済みの場合: クリアページへ遷移
            final escapeTimeKey = "escapeTime_${event.id}";
            final escapeTime = prefs.getDouble(escapeTimeKey);
            
            if (escapeTime != null && escapeTime > 0) {
              // ClearPageに遷移
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ClearPage(
                    eventName: event.name,
                    eventId: event.id,
                    escapeTime: escapeTime,
                    onNavigateToEventDetail: (lib_models.Event event) {
                      // lib_models.Event を event_model.Event に変換
                      final convertedEvent = _convertEvent(event);
                      return IndividualEventScreen(event: convertedEvent);
                    },
                    onDismiss: () {
                      // イベント一覧ページ（最初のページ）に戻る
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                ),
              );
            } else {
              // escapeTimeが保存されていない場合は受付ページへ遷移
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ReceptionPage(event: event),
                ),
              );
            }
          } else {
            // 未クリアの場合: 受付ページへ遷移
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ReceptionPage(event: event),
              ),
            );
          }
        },
        isThreeLine: event.comment != null && event.comment!.isNotEmpty,
      ),
        ],
      ),
    );
  }
}

// PasswordInputView, AdminView (ダミー)
class PasswordInputPage extends StatefulWidget {
  final Function(bool) onPasswordVerified;
  const PasswordInputPage({super.key, required this.onPasswordVerified});

  @override
  State<PasswordInputPage> createState() => _PasswordInputPageState();
}

class _PasswordInputPageState extends State<PasswordInputPage> {
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;

  void _verifyPassword() {
    const correctPassword = '1115'; // 管理者認証のパスワード
    if (_passwordController.text == correctPassword) {
      widget.onPasswordVerified(true);
      Navigator.pop(context);
    } else {
      setState(() {
        _errorMessage = '暗証番号が間違っています';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パスワード入力')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '暗証番号',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _verifyPassword,
              child: const Text('認証'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}

class AdminPage extends StatefulWidget {
  final List<lib_models.Event> events;
  final VoidCallback onSave;
  const AdminPage({super.key, required this.events, required this.onSave});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final RevenueCatService _revenueCatService = RevenueCatService();
  bool _isLoading = false;
  bool _hasPro = false;

  @override
  void initState() {
    super.initState();
    _checkProStatus();
    _setupCustomerInfoListener();
  }

  /// Proエンタイトルメントの状態をチェック
  Future<void> _checkProStatus() async {
    try {
      await _revenueCatService.refreshCustomerInfo();
      if (mounted) {
        setState(() {
          _hasPro = _revenueCatService.hasProEntitlement();
        });
      }
    } catch (e) {
      debugPrint('❌ [AdminPage] Error checking Pro status: $e');
    }
  }

  /// 顧客情報の変更を監視
  void _setupCustomerInfoListener() {
    _revenueCatService.customerInfoStream.listen((customerInfo) {
      if (mounted) {
        setState(() {
          _hasPro = _revenueCatService.hasProEntitlement();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者ページ'),
        actions: [
          // 新規イベント作成ボタン（Pro購入が必要）
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _hasPro ? () => _navigateToEventTitleEdit(context, null) : _showProRequiredDialog,
            tooltip: _hasPro ? '新規イベント作成' : '主催者用購入が必要です',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.events.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.event_note, size: 60, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'イベントがありません',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToEventTitleEdit(context, null),
                        icon: const Icon(Icons.add),
                        label: const Text('新規イベントを作成'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.events.length,
                  itemBuilder: (context, index) {
                    final event = widget.events[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          event.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event.eventDate != null)
                              Text(
                                '開催日: ${EventListPageState.formatDate(event.eventDate!)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            if (event.comment != null && event.comment!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  event.comment!,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Text(
                              '表示: ${event.isVisible ? "表示" : "非表示"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: event.isVisible ? Colors.green : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        onTap: _hasPro 
                          ? () => _navigateToProblemManagement(context, event)
                          : _showProRequiredDialog,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: _hasPro 
                                ? () => _navigateToEventTitleEdit(context, event)
                                : _showProRequiredDialog,
                              tooltip: _hasPro ? '編集' : '主催者用購入が必要です',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: _hasPro 
                                ? () => _showDeleteConfirmation(context, event)
                                : _showProRequiredDialog,
                              tooltip: _hasPro ? '削除' : '主催者用購入が必要です',
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }

  /// Pro購入が必要な場合のダイアログを表示
  void _showProRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('主催者用購入が必要です'),
        content: const Text('このサブスクリプションは、イベント運営者向けの問題作成・管理機能への年間アクセスを提供します。一般のゲームプレイユーザーは購入する必要はありません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPage(),
                ),
              );
            },
            child: const Text('主催者用を購入'),
          ),
        ],
      ),
    );
  }

  void _navigateToProblemManagement(BuildContext context, lib_models.Event event) async {
    // Pro購入チェック
    if (!_hasPro) {
      _showProRequiredDialog();
      return;
    }
    
    // ProblemManagementPageに遷移
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProblemManagementPage(
          event: event,
          onEventUpdated: (updatedEvent) {
            // イベントが更新されたらリストを更新
            widget.onSave();
          },
          onDelete: () {
            // イベントが削除されたらリストを更新
            widget.onSave();
          },
        ),
      ),
    );
    
    // 画面から戻ってきたらリストを更新
    widget.onSave();
  }

  void _navigateToEventTitleEdit(BuildContext context, lib_models.Event? event) async {
    // Pro購入チェック（新規作成の場合のみ）
    if (event == null && !_hasPro) {
      _showProRequiredDialog();
      return;
    }
    
    // 新規イベントの場合はデフォルトのEventオブジェクトを作成
    final eventToEdit = event ??
        lib_models.Event(
          name: '',
          duration: 60, // デフォルト値
          creationPasscode: '1115', // デフォルト値
          isVisible: true,
        );

    // EventTitleEditViewに遷移
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventTitleEditView(
          event: eventToEdit,
          onUpdate: (updatedEvent) {
            // EventTitleEditView内で既にFirebaseに保存されているので、
            // ここではリストを更新するだけ
            widget.onSave(); // イベントリストを更新
          },
        ),
      ),
    );
    
    // 画面から戻ってきたらリストを更新
    widget.onSave();
  }

  void _showEventEditDialog(BuildContext context, lib_models.Event? event) {
    showDialog(
      context: context,
      builder: (context) => _EventEditDialog(
        event: event,
        onSave: () {
          widget.onSave(); // イベントリストを更新
          Navigator.pop(context); // ダイアログを閉じる
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, lib_models.Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('イベントを削除'),
        content: Text('「${event.name}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteEvent(event);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteEvent(lib_models.Event event) async {
    setState(() => _isLoading = true);
    try {
      await _firebaseService.deleteEvent(event.id);
      widget.onSave(); // イベントリストを更新
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('イベントを削除しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _EventEditDialog extends StatefulWidget {
  final lib_models.Event? event;
  final VoidCallback onSave;
  const _EventEditDialog({required this.event, required this.onSave});

  @override
  State<_EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<_EventEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _commentController;
  late DateTime _eventDate;
  late bool _isVisible;
  bool _isSaving = false;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.name ?? '');
    _commentController = TextEditingController(text: widget.event?.comment ?? '');
    _eventDate = widget.event?.eventDate ?? DateTime.now();
    _isVisible = widget.event?.isVisible ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _saveEvent() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('イベントタイトルを入力してください')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final event = widget.event?.copyWith(
            name: title,
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
            eventDate: _eventDate,
            isVisible: _isVisible,
            lastUpdated: DateTime.now(),
          ) ??
          lib_models.Event(
            name: title,
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
            eventDate: _eventDate,
            isVisible: _isVisible,
            duration: 60, // デフォルト値
            creationPasscode: '1115', // デフォルト値
          );

      await _firebaseService.saveEvent(event);
      
      if (mounted) {
        widget.onSave();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.event == null
                ? 'イベントを作成しました'
                : 'イベントを更新しました'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _eventDate) {
      setState(() => _eventDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.event == null ? '新規イベント作成' : 'イベント編集',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'イベントタイトル *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'コメント',
                  border: OutlineInputBorder(),
                  hintText: 'イベントの説明やコメントを入力',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('開催日時'),
                subtitle: Text(EventListPageState.formatDate(_eventDate)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDate,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('イベント一覧に表示'),
                value: _isVisible,
                onChanged: (value) => setState(() => _isVisible = value),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveEvent,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.event == null ? '作成' : '保存'),
                  ),
                ],
              ),
            ],
          ),
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
  List<lib_models.Event> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showError = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    // ログイン直後のFirebaseアクセスを遅延させる
    // Firebaseの初期化が完了するまで少し待つ
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadEvents();
      }
    });
  }
  
  // SwiftUIの sortedEvents に相当するGetter
  List<lib_models.Event> get _sortedEvents {
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
    // 既にロード中の場合はスキップ（ただし、初回ロード時は実行）
    if (_isLoading && _events.isNotEmpty && mounted) return;

    // Firebaseが初期化されているか確認
    if (!_firebaseService.isConfigured) {
      print("⚠️ [EventListPage] Firebaseが初期化されていません。再試行します...");
      // Firebaseの初期化を待つ
      await Future.delayed(const Duration(seconds: 1));
      if (!_firebaseService.isConfigured) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Firebaseが初期化されていません。アプリを再起動してください。';
            _showError = true;
            _isLoading = false;
          });
        }
        return;
      }
    }

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
        String errorMsg = error.toString();
        
        // 権限エラーの場合、より分かりやすいメッセージを表示
        if (errorMsg.contains('permission-denied')) {
          errorMsg = 'Firebase Realtime Databaseのアクセス権限が設定されていません。\n\n'
              'Firebase Consoleでセキュリティルールを設定してください。\n'
              '詳細は FIREBASE_RULES.md を参照してください。';
        }
        
        setState(() {
          _errorMessage = errorMsg;
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
          // プレイヤー名変更ボタン
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PlayerNameEditPage(),
                ),
              );
            },
            tooltip: 'プレイヤー名変更',
          ),
          // 管理者ボタン (ToolbarItem(placement: .navigationBarTrailing))
          // サブスクリプションページに遷移
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SubscriptionPage(),
                ),
              );
            },
            tooltip: 'サブスクリプション',
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
    // エラー表示
    if (_showError && _errorMessage != null) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red,
                ),
                const SizedBox(height: 20),
                const Text(
                  "エラーが発生しました",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (_errorMessage!.contains('permission-denied')) ...[
                  const SizedBox(height: 20),
                  Text(
                    "【設定手順】\n"
                    "1. Firebase Console (https://console.firebase.google.com/) にアクセス\n"
                    "2. プロジェクト 'dassyutsu2' を選択\n"
                    "3. 左メニューから「Realtime Database」→「ルール」タブを開く\n"
                    "4. firebase-database-rules.json の内容をコピー＆ペースト\n"
                    "5. 「公開」ボタンをクリック\n"
                    "6. アプリを再起動",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showError = false;
                          _errorMessage = null;
                        });
                        _loadEvents();
                      },
                      child: const Text("再試行"),
                    ),
                    if (_errorMessage!.contains('permission-denied')) ...[
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Firebase Consoleを開く（ブラウザで開く）
                          // 注意: macOSでは直接ブラウザを開くことはできないため、
                          // ユーザーに手動で開いてもらう必要があります
                        },
                        icon: const Icon(Icons.open_in_browser, size: 18),
                        label: const Text("設定手順を見る"),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    
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