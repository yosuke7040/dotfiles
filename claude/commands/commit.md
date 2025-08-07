# /commit コマンド

gitの変更内容を分析し、適切なコミットメッセージを提案するカスタムコマンドです。

```yaml
---
command: "/commit"
category: "Version-Control"
purpose: "Intelligent git commit message generation based on staged changes"
wave-enabled: false
performance-profile: "standard"
---
```

## 概要

`/commit` コマンドは、ステージングされた変更内容を分析し、Conventional Commits形式に従った適切なコミットメッセージを提案します。変更の種類、影響範囲、破壊的変更の有無を自動的に検出し、プロジェクトの規約に沿ったメッセージを生成します。

**デフォルトは日本語**でメッセージを生成しますが、`--en` フラグで英語メッセージも生成可能です。

## 機能

### 自動検出
- **変更タイプ**: feat/fix/docs/style/refactor/test/chore を自動判定
- **スコープ**: 変更されたファイルパスから影響範囲を特定
- **破壊的変更**: APIの互換性を破る変更を検出
- **言語**: 日本語/英語でのメッセージ生成

### 分析内容
1. `git diff --cached` で変更内容を取得
2. ファイルパターンと変更内容から変更タイプを推定
3. 変更の重要度と影響範囲を評価
4. 簡潔で分かりやすいメッセージを生成

## 使用方法

### 基本的な使い方
```bash
# ステージングされた変更を分析してメッセージを提案（日本語）
/commit

# 英語でメッセージを生成
/commit --en
# または
/commit --lang en

# 特定のタイプを指定
/commit --type feat --scope auth

# 破壊的変更として扱う
/commit --breaking
```

### フラグオプション

- `--type [type]`: コミットタイプを明示的に指定
  - `feat`: 新機能
  - `fix`: バグ修正
  - `docs`: ドキュメントのみの変更
  - `style`: コードの意味に影響しない変更（空白、フォーマット等）
  - `refactor`: バグ修正や機能追加を含まないコード変更
  - `test`: テストの追加や修正
  - `chore`: ビルドプロセスやツールの変更

- `--scope [area]`: 変更の影響範囲を指定（例: auth, ui, api）

- `--breaking`: 破壊的変更フラグ（BREAKING CHANGE を含める）

- `--lang [ja|en]`: メッセージ言語（デフォルト: ja）
- `--en`: 英語でメッセージを生成（`--lang en` のショートカット）

## 動作詳細

### Persona自動起動
- **Scribe**: コミットメッセージの文章作成
- **Analyzer**: 変更内容の分析と分類

### MCP統合
- **Sequential**: 複雑な変更パターンの分析
- **Context7**: プロジェクト固有のコミット規約の参照

### ツール連携
- **Bash**: gitコマンドの実行
- **Read**: 変更ファイルの内容確認
- **Grep**: パターンマッチングによる変更検出

## 出力例

### 新機能追加

日本語（デフォルト）:
```
feat(auth): OAuth2認証を追加

- OAuth2プロバイダー統合を実装
- トークンリフレッシュ機能を追加
- ユーザーモデルにOAuth関連フィールドを追加
```

英語（--en フラグ使用時）:
```
feat(auth): add OAuth2 authentication

- Implement OAuth2 provider integration
- Add token refresh mechanism
- Update user model with OAuth fields
```

### バグ修正

日本語（デフォルト）:
```
fix(api): データ取得時の競合状態を解決

以前は同時リクエストによりデータ破損が発生する可能性がありました。
適切なミューテックスロックを追加し、競合状態を防止します。
```

英語（--en フラグ使用時）:
```
fix(api): resolve race condition in data fetching

Previously, concurrent requests could cause data corruption.
This fix adds proper mutex locking to prevent race conditions.
```

### 破壊的変更

日本語（デフォルト）:
```
feat(api)!: ユーザー認証フローを更新

BREAKING CHANGE: /api/loginエンドポイントは
ユーザー名の代わりにメールアドレスが必要になりました。
全てのクライアントアプリケーションを新しい認証形式に
更新してください。
```

英語（--en フラグ使用時）:
```
feat(api)!: update user authentication flow

BREAKING CHANGE: The /api/login endpoint now requires
email instead of username. Update all client applications
to use the new authentication format.
```

## ベストプラクティス

1. **変更をステージング**: コマンド実行前に `git add` で変更をステージング
2. **スコープの明確化**: 影響範囲が明確な場合は `--scope` で指定
3. **破壊的変更の明示**: APIの変更など互換性を破る場合は `--breaking` を使用
4. **言語の統一**: プロジェクトの規約に従って言語を選択

## 注意事項

- ステージングされていない変更は分析対象外
- 大規模な変更の場合は、複数の小さなコミットに分割することを推奨
- 自動生成されたメッセージは提案であり、必要に応じて編集可能