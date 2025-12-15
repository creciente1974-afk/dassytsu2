import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'lib/models/event.dart';
import 'lib/models/problem.dart';
import 'lib/models/hint.dart';
import 'lib/pages/clear_page.dart';
import 'lib/pages/camera_check_page.dart';
import 'lib/pages/game_over_page.dart';
import 'individual_event_screen.dart';

// プレースホルダークラス (FirebaseServiceの代替)
class FirebaseService {
  static final FirebaseService shared = FirebaseService._internal();
  FirebaseService._internal();
  // 実際のFirebaseロジックは実装されていません
}

// ClearViewはClearPageに置き換えられました
// GameOverViewはGameOverPageに置き換えられました

// CameraCheckViewは削除され、CameraCheckPageを使用します


// ===============================================
// 2. GameView (メイン画面)
// ===============================================

class GameView extends StatefulWidget {
  final Event event;
  final String teamId;

  const GameView({required this.event, this.teamId = 'default-team', super.key});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  int _currentProblemIndex = 0;
  late int _remainingTime; // 秒単位（イベント全体の残り時間）
  int _problemElapsedTime = 0; // 現在の問題の経過時間（秒）
  late DateTime _startTime; // ゲーム開始時刻
  Timer? _timer;
  String _answerText = '';
  Set<String> _displayedHints = {}; // Hint ID (String) を保持
  bool _showClearView = false;
  bool _showGameOverView = false;
  bool _shouldMoveToNextProblem = false; // 認証クリア後に次の問題へ遷移するフラグ

  final TextEditingController _answerController = TextEditingController();

  Problem get _currentProblem {
    if (widget.event.problems.isEmpty) {
      throw StateError('イベントに問題が設定されていません');
    }
    if (_currentProblemIndex < 0 || _currentProblemIndex >= widget.event.problems.length) {
      throw RangeError('問題のインデックスが範囲外です: $_currentProblemIndex');
    }
    return widget.event.problems[_currentProblemIndex];
  }

  @override
  void initState() {
    super.initState();
    
    // イベントに問題が設定されているかチェック
    if (widget.event.problems.isEmpty) {
      print("❌ [GameView] イベントに問題が設定されていません");
      // エラー状態を設定（buildメソッドでエラー画面を表示）
      return;
    }
    
    _remainingTime = widget.event.duration * 60; // 分を秒に変換
    _startTime = DateTime.now();
    _startTimer();
    print("✅ [GameView] 初期化完了 - 問題数: ${widget.event.problems.length}, 制限時間: ${widget.event.duration}分");
  }

  @override
  void dispose() {
    _stopTimer();
    _answerController.dispose();
    super.dispose();
  }

  // プレイヤー名を取得 (SwiftのUserDefaultsの代替)
  // Future<String?> _getPlayerName() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   final key = 'playerName_${widget.event.id}';
  //   return prefs.getString(key);
  // }

  // タイムカウントをHH:MM:SS形式に変換
  String _timeString(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // タイマー開始
  void _startTimer() {
    _stopTimer(); // 既存のタイマーを停止してから新しいタイマーを開始
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime -= 1;
          _problemElapsedTime += 1;
          _checkHints();
        } else {
          _handleTimeOver();
        }
      });
    });
  }

  // タイマー停止
  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ヒント表示チェック
  void _checkHints() {
    // イベントに問題が設定されていない場合は何もしない
    if (widget.event.problems.isEmpty) {
      return;
    }
    
    try {
      for (final hint in _currentProblem.hints) {
        // timeOffsetは秒単位なので、そのまま比較
        if (hint.timeOffset <= _problemElapsedTime &&
            !_displayedHints.contains(hint.id)) {
          setState(() {
            _displayedHints.add(hint.id);
          });
        }
      }
    } catch (e) {
      print("⚠️ [GameView] ヒントチェック中にエラー: $e");
    }
  }

  // 回答チェック
  void _checkAnswer() {
    _dismissKeyboard();

    final trimmedAnswer = _answerText.trim().toLowerCase();
    final correctAnswer = _currentProblem.answer.toLowerCase();

    if (trimmedAnswer == correctAnswer) {
      // 正解
      print('✅ [GameView] 問題 ${_currentProblemIndex + 1} の回答が正解でした');
      _stopTimer(); // タイマーを一時停止

      if (_currentProblem.requiresCheck) {
        // 画像認証機能がオン
        print('📸 [GameView] 問題 ${_currentProblemIndex + 1} の画像認証が必要です。チェックページを表示します');
        // キーボードが閉じるのを待つ
        Future.delayed(const Duration(milliseconds: 100), () {
          _showCameraCheckSheet(context);
        });
      } else {
        // 画像認証機能がオフ
        print('⏭️ [GameView] 問題 ${_currentProblemIndex + 1} の画像認証機能がオフです。次の問題へ遷移します');
        _moveToNextProblem();
      }
    } else {
      // 不正解
      print('❌ [GameView] 回答が不正解でした');
      setState(() {
        _answerText = '';
        _answerController.clear();
      });
      // 必要に応じてユーザーにフィードバックを表示 (e.g., SnackBar)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不正解です。もう一度お試しください。')),
      );
    }
  }

  // キーボードを閉じる (SwiftのdismissKeyboardの代替)
  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  // カメラチェックページを表示
  void _showCameraCheckSheet(BuildContext context) {
    _dismissKeyboard();
    _stopTimer(); // タイマーを一時停止
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CameraCheckPage(
          problem: _currentProblem,
          eventId: widget.event.id,
          problemIndex: _currentProblemIndex,
          teamId: widget.teamId,
          onApproved: () {
            // 認証クリア: 次の問題へ遷移するフラグを設定
            print('✅ [GameView] 問題 ${_currentProblemIndex + 1} の画像認証がクリアされました');
            _shouldMoveToNextProblem = true;
            Navigator.of(context).pop(); // 認証ページを閉じる
          },
          onRejected: () {
            // 認証失敗: チェックページに留まる（CameraCheckPage内で処理）
            print('❌ [GameView] 画像認証が拒否されました');
          },
        ),
      ),
    ).then((_) {
      // ページが閉じられたときに実行される
      _dismissKeyboard();

      if (_shouldMoveToNextProblem) {
        _shouldMoveToNextProblem = false;
        // ページが完全に閉じられた後に次の問題へ遷移
        Future.delayed(const Duration(milliseconds: 100), () {
          _moveToNextProblem();
        });
      } else {
        // 認証をキャンセルした場合や、認証失敗でページが閉じられた場合
        _startTimer(); // キャンセルした場合、タイマーを再開
      }
    });
  }

  // 次の問題へ遷移
  void _moveToNextProblem() {
    // 現在の問題が最後の問題かどうかをチェック
    final isLastProblem = _currentProblemIndex >= widget.event.problems.length - 1;

    if (!isLastProblem) {
      // 次の問題へ遷移
      final nextProblemIndex = _currentProblemIndex + 1;
      setState(() {
        _currentProblemIndex = nextProblemIndex;
        _answerText = '';
        _answerController.clear();
        _displayedHints.clear();
        _problemElapsedTime = 0; // 問題ごとのタイマーをリセット
      });
      _startTimer(); // タイマーを再開
      print('✅ [GameView] 問題 ${_currentProblemIndex + 1} へ遷移しました');
    } else {
      // 全ての問題をクリアしたので、クリアページへ移行
      print('🎉 [GameView] 全ての問題をクリアしました！クリアページへ移行します');
      _stopTimer();
      _showClearScreen();
    }
  }

  // タイムオーバー処理
  void _handleTimeOver() {
    _stopTimer();
    Vibration.vibrate(duration: 500); // バイブレーション

    _showGameOverScreen();
  }

  // 脱出タイムを計算
  double _calculateEscapeTime() {
    return DateTime.now().difference(_startTime).inSeconds.toDouble();
  }

  // クリア画面への遷移
  void _showClearScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ClearPage(
          eventName: widget.event.name,
          eventId: widget.event.id,
          escapeTime: _calculateEscapeTime(),
          onNavigateToEventDetail: (event) => IndividualEventScreen(event: event),
          onDismiss: () {
            // クリアページから戻る場合は、イベント一覧ページに戻る
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
      (Route<dynamic> route) => false, // スタックを全てクリア
    );
  }

  // ゲームオーバー画面への遷移
  void _showGameOverScreen() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => GameOverPage(
          eventName: widget.event.name,
          eventId: widget.event.id,
        ),
      ),
      (Route<dynamic> route) => false, // スタックを全てクリア
    );
  }

  @override
  Widget build(BuildContext context) {
    // ゲームオーバーまたはクリア画面が表示される場合は、メインのUIを構築しない
    if (_showClearView || _showGameOverView) {
      return Container();
    }

    // イベントに問題が設定されていない場合のエラー画面
    if (widget.event.problems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('エラー'),
          automaticallyImplyLeading: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'このイベントには問題が設定されていません',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  '管理者に問い合わせてください',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('戻る'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // 戻るボタンを非表示
        title: const Text('ゲーム進行中'),
      ),
      body: Column(
        children: [
          // タイムカウント表示
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.watch_later_outlined,
                  color: _remainingTime <= 60 ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  _timeString(_remainingTime),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: _remainingTime <= 60 ? Colors.red : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // スクロール可能な問題コンテンツ
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 問題番号表示
                    Text(
                      '問題 ${_currentProblemIndex + 1} / ${widget.event.problems.length}',
                      style: const TextStyle(
                          fontSize: 16, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // 問題テキスト
                    if (_currentProblem.text != null)
                      Text(
                        _currentProblem.text!,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),

                    // メディア表示（動画または画像）
                    MediaView(mediaURL: _currentProblem.mediaURL)
                        .constraints(const BoxConstraints(maxHeight: 300))
                        .clipRRect(BorderRadius.circular(12)),
                    const SizedBox(height: 20),

                    // 表示されたヒント
                    if (_displayedHints.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "ヒント",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange),
                          ),
                          const SizedBox(height: 8),
                          ..._currentProblem.hints
                              .where((h) => _displayedHints.contains(h.id))
                              .map((hint) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        hint.content,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  )),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // 回答入力フィールド
                    const Text(
                      "回答",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _answerController,
                      onChanged: (text) => _answerText = text,
                      decoration: InputDecoration(
                        hintText: '答えを入力してください',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _checkAnswer(),
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _checkAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "回答する",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================================
// 3. MediaView (メディア表示)
// ===============================================

class MediaView extends StatefulWidget {
  final String mediaURL;

  const MediaView({required this.mediaURL, super.key});

  @override
  State<MediaView> createState() => _MediaViewState();
}

enum MediaType { video, image, youtube, unknown }

class _MediaViewState extends State<MediaView> {
  MediaType _mediaType = MediaType.unknown;
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _determineMediaType(widget.mediaURL);
    _setupMedia();
  }

  @override
  void didUpdateWidget(covariant MediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaURL != widget.mediaURL) {
      _disposeControllers();
      _determineMediaType(widget.mediaURL);
      _setupMedia();
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _disposeControllers() {
    _videoController?.dispose();
    _youtubeController?.dispose();
    _videoController = null;
    _youtubeController = null;
  }

  void _determineMediaType(String url) {
    _mediaType = MediaType.unknown;
    if (url.isEmpty) return;

    final lowercased = url.toLowerCase();

    // YouTubeのURLを最初にチェック
    if (lowercased.contains("youtube.com") || lowercased.contains("youtu.be")) {
      _mediaType = MediaType.youtube;
    }
    // 動画ファイル形式をチェック
    else if (lowercased.contains(".mp4") ||
        lowercased.contains(".mov") ||
        lowercased.contains(".m4v") ||
        lowercased.contains(".avi") ||
        lowercased.contains(".webm") ||
        lowercased.contains("video")) {
      _mediaType = MediaType.video;
    }
    // 画像ファイル形式をチェック
    else if (lowercased.contains(".jpg") ||
        lowercased.contains(".jpeg") ||
        lowercased.contains(".png") ||
        lowercased.contains(".gif") ||
        lowercased.contains(".webp") ||
        lowercased.contains(".svg") ||
        lowercased.contains("image")) {
      _mediaType = MediaType.image;
    }
    // HTTP/HTTPSで始まるURLはデフォルトで画像として扱う（Swiftのロジックに倣う）
    else if (url.startsWith("http://") || url.startsWith("https://")) {
       _mediaType = MediaType.image;
    }
  }

  String? _getYoutubeVideoId(String urlString) {
    return YoutubePlayer.convertUrlToId(urlString);
  }

  void _setupMedia() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    switch (_mediaType) {
      case MediaType.video:
        try {
          final url = Uri.parse(widget.mediaURL);
          _videoController = VideoPlayerController.networkUrl(url);
          await _videoController!.initialize();
          _videoController!.setLooping(true);
          _videoController!.play();
          setState(() {
            _isLoading = false;
          });
          print('✅ [MediaView] 動画の準備が完了しました: ${widget.mediaURL}');
        } catch (e) {
          print('❌ [MediaView] 動画の読み込みに失敗: $e');
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        break;

      case MediaType.youtube:
        final videoId = _getYoutubeVideoId(widget.mediaURL);
        if (videoId != null) {
          _youtubeController = YoutubePlayerController(
            initialVideoId: videoId,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              mute: false,
              disableDragSeek: false,
              loop: true,
              isLive: false,
              forceHD: false,
              enableCaption: false,
            ),
          );
          _youtubeController!.addListener(() {
            if (_youtubeController!.value.hasError) {
              setState(() => _hasError = true);
              print('❌ [MediaView] YouTube Player Error: ${_youtubeController!.value}'); // error field not available
            }
          });
          setState(() {
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
        break;

      case MediaType.image:
        // Image.networkは自動で読み込みを行うため、特別なセットアップは不要
        setState(() {
          _isLoading = false;
        });
        break;

      case MediaType.unknown:
        setState(() {
          _isLoading = false;
        });
        break;
    }
  }

  Widget _placeholderView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo,
            size: 50,
            color: Colors.grey,
          ),
          const SizedBox(height: 8),
          Text(
            _hasError ? "メディアの読み込みに失敗しました" : "メディアなし",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey.shade200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                _mediaType == MediaType.video ? "動画を読み込み中..." : "メディアを読み込み中...",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasError || _mediaType == MediaType.unknown) {
      return _placeholderView();
    }

    switch (_mediaType) {
      case MediaType.video:
        return _videoController != null && _videoController!.value.isInitialized
            ? AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            : _placeholderView();

      case MediaType.youtube:
        return YoutubePlayer(
          controller: _youtubeController!,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.blueAccent,
          onReady: () {
            print('✅ [MediaView] YouTubeプレイヤーの準備が完了');
          },
          onEnded: (metaData) {
            _youtubeController!.load(_youtubeController!.initialVideoId); // ループ再生
          },
        );

      case MediaType.image:
        return Image.network(
          widget.mediaURL,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return _placeholderView();
          },
        );

      case MediaType.unknown:
        return _placeholderView();
    }
  }
}

// ===============================================
// 4. Preview (テスト用のデータ)
// ===============================================

void main() {
  // アプリケーションのエントリーポイント
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // プレビュー用のダミーデータ (Swiftの#Previewに対応)
    final dummyEvent = Event(
      id: 'preview-event-id',
      name: 'サンプルイベント',
      duration: 60, // 60分
      problems: [
        Problem(
          id: 'problem-1-id',
          text: "問題1: この動画に隠されたメッセージを解読せよ。",
          mediaURL:
              "https://sample-videos.com/video123/mp4/720/big_buck_bunny_720p_10mb.mp4", // ダミーの動画URL
          answer: "答え1",
          requiresCheck: true,
          checkText: "赤いベンチを撮影してください",
          hints: [
            Hint(id: 'hint-1-1', content: "ヒント1: 動画の最初の方に注意深く目を凝らして。", timeOffset: 60), // 60秒後
            Hint(id: 'hint-1-2', content: "ヒント2: メッセージは逆さまになっている。", timeOffset: 180), // 180秒後
          ],
        ),
        Problem(
          id: 'problem-2-id',
          text: "問題2: 謎の画像に隠された数字を見つけ出せ。",
          mediaURL:
              "https://picsum.photos/id/237/800/600", // ダミーの画像URL
          answer: "答え2",
          requiresCheck: false,
          hints: [],
        ),
      ],
    );

    return MaterialApp(
      title: 'Dassyutsu Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: NavigationWrapper(event: dummyEvent),
    );
  }
}

// NavigationStackの代わりとして、GameViewを直接表示するラッパー
class NavigationWrapper extends StatelessWidget {
  final Event event;
  const NavigationWrapper({required this.event, super.key});

  @override
  Widget build(BuildContext context) {
    return GameView(event: event, teamId: 'preview-team');
  }
}

// Widgetの制約を簡略化するエクステンション (SwiftUIの.frame().cornerRadius()に対応)
extension WidgetExtensions on Widget {
  Widget constraints(BoxConstraints constraints) {
    return Container(constraints: constraints, child: this);
  }

  Widget clipRRect(BorderRadius borderRadius) {
    return ClipRRect(borderRadius: borderRadius, child: this);
  }
}