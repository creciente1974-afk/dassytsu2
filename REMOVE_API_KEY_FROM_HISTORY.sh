#!/bin/bash

# Git履歴からFirebase設定ファイル（APIキー含む）を完全に削除するスクリプト
# 注意: この操作は履歴を書き換えます。チームメンバーに通知してから実行してください。

echo "⚠️  警告: この操作はGit履歴を書き換えます"
echo "⚠️  チームメンバーがいる場合は、事前に通知してください"
echo ""
read -p "続行しますか？ (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "操作をキャンセルしました"
    exit 1
fi

echo ""
echo "🔍 Git履歴からFirebase設定ファイルを削除中..."

# git filter-branchを使用して履歴から削除
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch android/app/google-services.json ios/Runner/GoogleService-Info.plist" \
  --prune-empty --tag-name-filter cat -- --all

echo ""
echo "🧹 不要な参照を削除中..."

# バックアップの削除
rm -rf .git/refs/original/

# ガベージコレクション
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "✅ 完了しました"
echo ""
echo "次のステップ:"
echo "1. git log で履歴を確認してください"
echo "2. 問題がなければ: git push origin --force --all"
echo "3. タグがある場合: git push origin --force --tags"
echo ""
echo "⚠️  注意: force pushは慎重に実行してください"

