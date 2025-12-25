import 'package:flutter/material.dart';
import '../../event_list_page.dart';

class GameOverPage extends StatelessWidget {
  // Swiftの let eventName: String に相当
  final String eventName;
  final String eventId;

  const GameOverPage({
    required this.eventName,
    required this.eventId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Scaffoldで画面の基本構造を作成
    return Scaffold(
      // Swiftの .navigationBarBackButtonHidden(true) に相当
      appBar: AppBar(
        automaticallyImplyLeading: false, // 戻るボタンを非表示
      ),
      
      // Swiftの VStack(spacing: 30) に相当
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(), // Spacer()

          // MARK: - ゲームオーバーアイコン部分 (ZStackに相当)
          _buildGameOverIcon(),
          
          const SizedBox(height: 30), // Vstack(spacing: 30) の間隔

          // MARK: - タイトル
          // Swiftの Text("ゲームオーバー") に相当
          const Text(
            "ゲームオーバー",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 34, // largeTitle
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          
          const SizedBox(height: 10),

          // MARK: - 説明文
          // Swiftの Text("\(eventName)の\n制限時間が終了しました") に相当
          Text(
            "$eventNameの\n制限時間が終了しました",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20, // title2
              color: Colors.grey[700], // secondary
              height: 1.4,
            ),
          ),
          
          const Spacer(), // Spacer()

          // MARK: - メイン画面へ戻るボタン (Button(action: { dismiss() }) に相当)
          Padding(
            padding: const EdgeInsets.only(left: 40, right: 40, bottom: 40),
            child: ElevatedButton.icon(
              // イベント一覧ページに戻る
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const EventListPage(),
                  ),
                  (Route<dynamic> route) => false, // スタックを全てクリア
                );
              },
              icon: const Icon(Icons.home, color: Colors.white), // house.fill
              label: const Text(
                "メイン画面へ戻る",
                style: TextStyle(
                  fontSize: 18, // headline
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue, // background(Color.blue)
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12), // cornerRadius(12)
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ZStack部分を抽出したプライベートウィジェット
  Widget _buildGameOverIcon() {
    // Swiftの ZStack に相当
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Swiftの Circle().fill(Color.red.opacity(0.1)) に相当
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.1),
            ),
          ),
          
          // Swiftの VStack(spacing: 10) に相当
          Column(
            mainAxisSize: MainAxisSize.min, // 要素のサイズに合わせる
            children: [
              // Swiftの Image(systemName: "exclamationmark.triangle.fill") に相当
              const Icon(
                Icons.warning_amber_rounded, // 警告アイコン
                size: 80, 
                color: Colors.red,
              ),
              
              const SizedBox(height: 10), // VStack(spacing: 10) の間隔

              // Swiftの Image(systemName: "clock.fill") に相当
              const Icon(
                Icons.access_time_filled, // 時計アイコン
                size: 40, 
                color: Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }
}