# 直接テスト方法

## 🔍 現在の状況

- 「Firebase Realtime Database API」がAPIライブラリで見つからない
- 「Firebase Realtime Database Management API」のみ表示される
- 依然として `permission-denied` エラーが発生

## 💡 解決方法

### 方法1: 「有効なAPIとサービス」で確認

Firebase Realtime Database APIは、Firebaseプロジェクトを作成すると自動的に有効になることが多いです。

#### 手順

1. **Google Cloud Console** → `dassyutsu2` プロジェクト
2. **「API とサービス」→ 「有効なAPIとサービス」** をクリック
3. **検索バーで「firebasedatabase」を検索**
   - 「Firebase Realtime Database API」が表示されるか確認
   - サービス名: `firebasedatabase.googleapis.com`
4. **有効になっているか確認**
   - ✅ 有効になっている → 方法2へ
   - ❌ 有効になっていない → 「ライブラリ」から有効化

### 方法2: REST APIで直接テスト ⭐ 重要

Firebase Consoleでルールが機能しているか確認します。

#### 手順

1. **ターミナルで以下のコマンドを実行**

```bash
# ルートパスへのアクセステスト（ルールが `.read: true` の場合、authは不要）
curl -X GET "https://dassyutsu2-default-rtdb.asia-southeast1.firebasedatabase.app/.json"
```

2. **結果を確認**
   - ✅ データが返ってくる（例: `{}` や `{"events": {...}}`） → ルールは正しく設定されています（アプリ側の問題）
   - ❌ `Permission denied` → ルールに問題があります
   - ❌ `404 Not Found` → データベースインスタンスが見つかりません
   - ❌ `401 Unauthorized` → 認証が必要です

### 方法3: Firebase Consoleで直接データを確認

Firebase Consoleでデータが読み取れるか確認することで、ルールが実際に機能しているか確認できます。

#### 手順

1. **Firebase Console** → **Realtime Database** → **データ**タブ
2. **ルートパス（`/`）にデータが表示されるか確認**
   - ✅ 表示される → ルールは正しく設定されています（アプリ側の問題）
   - ❌ 表示されない → ルールに問題がある可能性があります

### 方法4: ルールを最もシンプルな形に変更

ルールを最もシンプルな形に変更して、問題を切り分けます。

#### 手順

1. **Firebase Console** → **Realtime Database** → **ルール**タブ
2. **ルールを以下のように変更**

```json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
```

3. **「公開」ボタンをクリック**
4. **5-10分待つ**
5. **アプリを再起動**

### 方法5: データベースインスタンスの設定を確認

データベースインスタンスの設定に問題がある可能性があります。

#### 手順

1. **Firebase Console** → **Realtime Database**
2. **データベースインスタンスを選択**
3. **「設定」タブをクリック**
4. **以下の設定を確認**
   - リージョン: `asia-southeast1`
   - モード: **テストモード**または**本番モード**
   - ルール: 正しく設定されているか

## 🎯 推奨される順序

1. **方法2: REST APIで直接テスト** ⭐ 最重要（ルールが機能しているか確認）
2. **方法3: Firebase Consoleで直接データを確認**
3. **方法1: 「有効なAPIとサービス」で確認**
4. **方法4: ルールを最もシンプルな形に変更**
5. **方法5: データベースインスタンスの設定を確認**

## 📋 確認チェックリスト

- [ ] REST APIで直接アクセスできるか確認
- [ ] Firebase Consoleでデータが読み取れるか確認
- [ ] 「有効なAPIとサービス」で「firebasedatabase」を検索
- [ ] ルールを最もシンプルな形に変更
- [ ] データベースインスタンスの設定を確認




