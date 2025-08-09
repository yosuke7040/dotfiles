# /pr - GitHub Pull Request Description Generator

GitHubのPull Request descriptionを生成するカスタムコマンドです。

## 使い方

```
/pr [変更の概要]
```

## オプション

- `--simple`: 最小限の項目のみ生成（背景・変更内容のみ）
- `--detailed`: すべての項目を含む詳細版を生成
- `--jira [TICKET-ID]`: JIRAチケットIDを自動的に背景に追加
- `--type [feat|fix|refactor|docs|test|chore]`: 変更タイプを指定

## 使用例

```
/pr ユーザー認証機能の実装
/pr --jira ABC-123 ログイン画面のUI改善
/pr --simple バグ修正
/pr --type feat --detailed 新規API実装
```

## テンプレート

<!-- GitHub Copilot コードレビューへの指示: このプルリクエストをレビューしてコメントする際には日本語でお願いします。 -->

## 背景

<!-- 変更の目的 or/and JIRAのリンク -->
{{background}}

## 変更内容

<!-- 今回のPRで何がかわるのか -->
{{changes}}

## この PR ではやらないこと

<!-- 別途対応のものや意図的にこのPRでやっていないことがあれば記載しておく -->
{{out_of_scope}}

## この PR に関連する後続タスク

<!-- このPRの後に予定しているタスクで明示した方がよいことがあれば記載しておく -->
{{follow_up_tasks}}

## 参考

<!-- その他参考になるようなリンク(仕様書，Slackのやりとり) -->
{{references}}

---

## コマンドの実行方法

このコマンドは以下の手順で動作します：

1. デフォルトブランチ（main/master）を自動検出
2. 現在のブランチとデフォルトブランチの差分を確認
3. 変更されたファイルの内容を分析
4. コミットメッセージから変更の意図を理解
5. 適切なPR descriptionを生成

### 実行時の処理フロー

1. **デフォルトブランチの検出**
   ```bash
   # リモートのデフォルトブランチを取得
   git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
   # または git rev-parse --abbrev-ref origin/HEAD
   ```

2. **差分の取得**
   ```bash
   # デフォルトブランチとの差分を確認
   git diff <default-branch>...HEAD
   git log <default-branch>..HEAD
   ```

3. **変更内容の分析**
   - 変更されたファイルのリスト
   - 各ファイルの変更行数
   - コミットメッセージの集約
   - ブランチ名からの文脈推測

### 生成時の考慮事項

- **背景**: なぜこの変更が必要なのか、どのような問題を解決するのか
- **変更内容**: 具体的に何が変わったのか、技術的な詳細
- **スコープ外**: 意図的に含めなかった変更や、別PRで対応予定の項目
- **後続タスク**: このPRのマージ後に必要となる作業
- **参考情報**: 関連するドキュメント、議論のリンクなど

### 自動生成される内容

以下の情報は自動的に取得・生成されます：

- デフォルトブランチ（main/master）の自動検出
- 変更されたファイルのリスト（`git diff --name-status`）
- 追加・削除された行数（`git diff --stat`）
- コミットメッセージの要約（`git log --oneline`）
- ブランチ名からの推測（feature/login → ログイン機能関連など）
- ファイルタイプからの推測（*.test.js → テスト追加など）

### デフォルトブランチとの差分確認

このコマンドは以下の方法でデフォルトブランチを検出し、差分を確認します：

```bash
# デフォルトブランチの自動検出（優先順位）
1. git symbolic-ref refs/remotes/origin/HEAD
2. git config init.defaultBranch
3. main または master の存在確認

# 差分の確認コマンド例
git diff origin/main...HEAD --name-status
git log origin/main..HEAD --oneline
```

### 注意事項

- 作業ブランチから実行してください（デフォルトブランチでの実行は避けてください）
- リモートの最新情報を取得するため、実行前に `git fetch` を推奨
- プライベートな情報が含まれていないか確認してからPRを作成してください
