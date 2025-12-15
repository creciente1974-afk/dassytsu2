// event_list_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'lib/models/event.dart'; // 正規のEventモデル
import 'lib/models/escape_record.dart'; // EscapeRecordモデル
import 'firebase_service.dart'; // FirebaseService
import 'event_title_edit_view.dart'; // EventTitleEditView
import 'individual_event_screen.dart'; // IndividualEventScreen
import 'lib/pages/problem_management_page.dart'; // ProblemManagementPage
import 'lib/pages/reception_page.dart'; // ReceptionPage

// EventCardView
class EventCardView extends StatelessWidget {
  final Event event;
  final String? gameOverEventId; // ゲームオーバーになったイベントID
  
  const EventCardView({
    super.key,
    required this.event,
    this.gameOverEventId,
  });

  // ランキング1位のレコードを取得
  EscapeRecord? get _bestRecord {
    if (event.records.isEmpty) return null;
    final sortedRecords = List<EscapeRecord>.from(event.records)
      ..sort((a, b) => a.escapeTime.compareTo(b.escapeTime));
    return sortedRecords.first;
  }

  // クリアタイムをフォーマット
  String _formatTime(double timeInterval) {
    final minutes = (timeInterval ~/ 60).toInt();
    final seconds = (timeInterval % 60).toInt();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  // ランキング1位のバッジウィジェット（画像の上に表示用）
  Widget _buildBestRecordBadge() {
    final bestRecord = _bestRecord;
    if (bestRecord == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ランキング1位の情報ウィジェット（コンテンツエリア用）
  Widget _buildBestRecordInfo() {
    final bestRecord = _bestRecord;
    if (bestRecord == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.emoji_events,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Text(
            "1位: ",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          Text(
            _formatTime(bestRecord.escapeTime),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // デバッグ用: イベント情報を確認
    if (event.name.isEmpty) {
      debugPrint("⚠️ [EventCardView] イベント名が空です (ID: ${event.id})");
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // イベント詳細画面への遷移
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => IndividualEventScreen(event: event),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 画像エリア
            if (event.cardImageUrl != null && event.cardImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: event.cardImageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 180,
                        placeholder: (context, url) => Container(
                          height: 180,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          height: 180,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      // ランキング1位のバッジ
                      _buildBestRecordBadge(),
                    ],
                  ),
                ),
              ),
            // コンテンツエリア
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 画像がない場合のランキング1位表示
                  if (event.cardImageUrl == null || event.cardImageUrl!.isEmpty)
                    _buildBestRecordInfo(),
                  Text(
                    event.name.isNotEmpty ? event.name : '名称未設定',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (event.eventDate != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '開催日: ${EventListPageState.formatDate(event.eventDate!)}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ),
                  if (event.comment != null && event.comment!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        event.comment!,
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 8),
                  // ゲームオーバーになったイベントの場合、「もう一度挑戦する」ボタンを表示
                  if (gameOverEventId != null && gameOverEventId == event.id)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // 受付ページへ遷移
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ReceptionPage(event: event),
                              ),
                            );
                          },
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            'もう一度挑戦する',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
  final List<Event> events;
  final VoidCallback onSave;
  const AdminPage({super.key, required this.events, required this.onSave});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者ページ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToEventTitleEdit(context, null),
            tooltip: '新規イベント作成',
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
              : Column(
                  children: [
                    // 新規イベント作成ボタン
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _navigateToEventTitleEdit(context, null),
                          icon: const Icon(Icons.add),
                          label: const Text('新規イベントを作成'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                    // イベント一覧
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextButton(
                                    onPressed: () => _navigateToProblemManagement(context, event),
                                    child: const Text(
                                      '問題編集',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => _showEventEditDialog(context, event),
                                    tooltip: '編集',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () => _showDeleteConfirmation(context, event),
                                    tooltip: '削除',
                                  ),
                                ],
                              ),
                              isThreeLine: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  void _navigateToEventTitleEdit(BuildContext context, Event? event) async {
    // 既存イベントを編集する場合、暗証番号認証を行う
    if (event != null) {
      final isAuthenticated = await _showPasscodeAuthDialog(context, event);
      if (!isAuthenticated) {
        // 認証失敗時は編集画面に遷移しない
        return;
      }
    }

    // 新規イベントの場合はデフォルトのEventオブジェクトを作成
    final eventToEdit = event ??
        Event(
          name: '',
          duration: 60, // デフォルト値
          creationPasscode: '', // 新規作成時は空（ユーザーが入力）
          isVisible: true,
        );

    // EventTitleEditViewに遷移
    final result = await Navigator.of(context).push(
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
    
    // 画面から戻ってきたらリストを更新（保存された場合）
    widget.onSave();
  }

  // 暗証番号認証ダイアログを表示
  Future<bool> _showPasscodeAuthDialog(BuildContext context, Event event) async {
    final passcode = event.creationPasscode;
    if (passcode == null || passcode.isEmpty) {
      // 暗証番号が設定されていない場合は認証をスキップ
      return true;
    }

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _PasscodeAuthDialog(correctPasscode: passcode);
      },
    ) ?? false;
  }

  void _navigateToProblemManagement(BuildContext context, Event event) async {
    // 問題管理ページに遷移する前に暗証番号認証を行う
    final isAuthenticated = await _showPasscodeAuthDialog(context, event);
    if (!isAuthenticated) {
      // 認証失敗時は問題管理ページに遷移しない
      return;
    }

    // 問題管理ページに遷移
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProblemManagementPage(
          event: event,
          onEventUpdated: (updatedEvent) {
            // イベントが更新された場合、リストを更新
            widget.onSave();
          },
          onDelete: () {
            // イベントが削除された場合、リストを更新
            widget.onSave();
          },
        ),
      ),
    );
    
    // 画面から戻ってきたらリストを更新（保存された場合）
    widget.onSave();
  }

  void _showEventEditDialog(BuildContext context, Event? event) async {
    // 既存イベントを編集する場合、暗証番号認証を行う
    if (event != null) {
      final isAuthenticated = await _showPasscodeAuthDialog(context, event);
      if (!isAuthenticated) {
        // 認証失敗時は編集ダイアログを表示しない
        return;
      }
    }

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

  void _showDeleteConfirmation(BuildContext context, Event event) {
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

  Future<void> _deleteEvent(Event event) async {
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

// 暗証番号認証ダイアログ
class _PasscodeAuthDialog extends StatefulWidget {
  final String correctPasscode;
  const _PasscodeAuthDialog({required this.correctPasscode});

  @override
  State<_PasscodeAuthDialog> createState() => _PasscodeAuthDialogState();
}

class _PasscodeAuthDialogState extends State<_PasscodeAuthDialog> {
  final TextEditingController _passcodeController = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // 暗証番号が空の場合は自動的に認証成功として閉じる
    if (widget.correctPasscode.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    }
  }

  void _verifyPasscode() {
    // 暗証番号が空の場合は認証成功として扱う
    if (widget.correctPasscode.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    
    if (_passcodeController.text == widget.correctPasscode) {
      Navigator.of(context).pop(true); // 認証成功
    } else {
      setState(() {
        _errorMessage = '暗証番号が間違っています';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('暗証番号認証'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _passcodeController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '暗証番号',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onSubmitted: (_) => _verifyPasscode(),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        ElevatedButton(
          onPressed: _verifyPasscode,
          child: const Text('認証'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }
}

class _EventEditDialog extends StatefulWidget {
  final Event? event;
  final VoidCallback onSave;
  const _EventEditDialog({required this.event, required this.onSave});

  @override
  State<_EventEditDialog> createState() => _EventEditDialogState();
}

class _EventEditDialogState extends State<_EventEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _commentController;
  late TextEditingController _passcodeController;
  late DateTime _eventDate;
  late bool _isVisible;
  late bool _isNewEvent;
  bool _isSaving = false;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _isNewEvent = widget.event == null;
    _titleController = TextEditingController(text: widget.event?.name ?? '');
    _commentController = TextEditingController(text: widget.event?.comment ?? '');
    _passcodeController = TextEditingController(text: widget.event?.creationPasscode ?? '');
    _eventDate = widget.event?.eventDate ?? DateTime.now();
    _isVisible = widget.event?.isVisible ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    _passcodeController.dispose();
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

    // 新規作成時は暗証番号が必須
    if (_isNewEvent) {
      final passcode = _passcodeController.text.trim();
      if (passcode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暗証番号を入力してください')),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final passcode = _isNewEvent 
          ? _passcodeController.text.trim()
          : (widget.event?.creationPasscode ?? '');
      
      final event = widget.event?.copyWith(
            name: title,
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
            eventDate: _eventDate,
            isVisible: _isVisible,
            lastUpdated: DateTime.now(),
          ) ??
          Event(
            name: title,
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
            eventDate: _eventDate,
            isVisible: _isVisible,
            duration: 60, // デフォルト値
            creationPasscode: passcode,
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
              // 新規作成時のみ暗証番号フィールドを表示
              if (_isNewEvent) ...[
                TextField(
                  controller: _passcodeController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '暗証番号 *',
                    border: OutlineInputBorder(),
                    hintText: 'イベント編集時に使用する暗証番号を入力',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
              ],
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
  final String? gameOverEventId; // ゲームオーバーになったイベントID
  
  const EventListPage({super.key, this.gameOverEventId});

  @override
  State<EventListPage> createState() => EventListPageState();
}

class EventListPageState extends State<EventListPage> {
  List<Event> _events = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showError = false;

  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    // 初期ロード時は強制的に実行
    _loadEvents(force: true);
  }
  
  // SwiftUIの sortedEvents に相当するGetter
  // isVisibleがfalseのイベントは一覧ページに表示しない
  List<Event> get _sortedEvents {
    print("🔍 [EventListPage] _sortedEvents計算開始: 全イベント数=${_events.length}");
    final visibleEvents = _events.where((e) => e.isVisible).toList();
    print("👁️ [EventListPage] 表示可能なイベント数: ${visibleEvents.length}件");

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

    print("✅ [EventListPage] _sortedEvents計算完了: ${visibleEvents.length}件");
    return visibleEvents;
  }

  // 日付のみで比較するヘルパー関数
  bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
  
  // SwiftUIの loadEvents() に相当
  Future<void> _loadEvents({bool force = false}) async {
    if (_isLoading && !force) {
      print("⏸️ [EventListPage] 既にロード中のためスキップ (isLoading: $_isLoading, force: $force)");
      return; // 既にロード中の場合はスキップ（force=trueの場合は強制実行）
    }

    print("🔄 [EventListPage] イベント読み込み開始 (force: $force, 現在のisLoading: $_isLoading)");

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showError = false;
    });

    try {
      print("📡 [EventListPage] FirebaseServiceのインスタンス確認: ${_firebaseService.isConfigured}");
      print("📡 [EventListPage] Firebaseからイベントを取得中...");
      
      final loadedEvents = await _firebaseService.getAllEvents();
      print("✅ [EventListPage] イベント取得成功: ${loadedEvents.length}件");

      if (mounted) {
        setState(() {
          _events = loadedEvents;
          _isLoading = false;
          print("✅ [EventListPage] UI更新完了: ${_events.length}件のイベントを取得");
          print("📊 [EventListPage] イベント詳細:");
          for (var event in _events) {
            print("  - ${event.name} (ID: ${event.id}, isVisible: ${event.isVisible}, eventDate: ${event.eventDate})");
          }
          final visibleCount = _sortedEvents.length;
          print("👁️ [EventListPage] 表示可能なイベント: $visibleCount件");
          
          if (_events.isEmpty) {
            print("⚠️ [EventListPage] イベントが0件です。Firebaseにデータが存在するか確認してください。");
          } else if (visibleCount == 0) {
            print("⚠️ [EventListPage] イベントは${_events.length}件ありますが、表示可能なイベント（isVisible=true）が0件です。");
          }
        });
      } else {
        print("⚠️ [EventListPage] Widgetがマウントされていないため、setStateをスキップ");
      }
    } catch (error, stackTrace) {
      print("❌ [EventListPage] エラー発生: ${error.toString()}");
      print("❌ [EventListPage] エラーの型: ${error.runtimeType}");
      print("❌ [EventListPage] スタックトレース: $stackTrace");
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
            onPressed: _showAdminSheet,
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
    // エラーが発生した場合の表示
    if (_showError && _errorMessage != null && !_isLoading) {
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
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => _loadEvents(force: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('再試行'),
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
    } else if (_sortedEvents.isEmpty) {
      // _eventsにデータがあるが、表示可能なイベントがない場合
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.visibility_off,
                  size: 60,
                  color: Colors.grey,
                ),
                const SizedBox(height: 20),
                const Text(
                  "表示可能なイベントがありません",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "管理者ページでイベントの表示設定を確認してください",
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
      print("📋 [EventListPage] イベントカードを表示: ${_sortedEvents.length}件");
      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _sortedEvents.length,
        separatorBuilder: (context, index) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          final event = _sortedEvents[index];
          print("🎴 [EventListPage] イベントカード作成: ${event.name} (ID: ${event.id}, isVisible: ${event.isVisible})");
          return EventCardView(
            event: event,
            gameOverEventId: widget.gameOverEventId,
          );
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
          onSave: () => _loadEvents(force: true), // 保存後にリストを強制的に再読み込み
        );
      },
    );
  }
}