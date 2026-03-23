# dev-cross-review

GitHub PR を 3 つの AI（Claude / Codex x2）で並列レビューし、結果を統合してレビューレポートを作成する Claude Code スキル。

## 仕組み

1. オーケストレーター（Claude Code）が 3 つのレビューエージェントをバックグラウンドで並列起動
2. 各エージェントが独立して PR の差分をレビュー
3. オーケストレーターが結果を収集・クロスリファレンスし、深刻度を判定して統合レポートを出力

## 前提条件

以下のツールがインストール・認証済みであること:

| ツール | 用途 | インストール |
|--------|------|-------------|
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | オーケストレーター + Agent 1 | `npm install -g @anthropic-ai/claude-code` |
| [Codex CLI](https://github.com/openai/codex) | Agent 2, 3 | `npm install -g @openai/codex` |

## セットアップ

`dev-cross-review` ディレクトリの内容を、ローカル環境のClaude Codeを起動するディレクトリの `/skills` 内にコピーする。

**注意**: **手順 1 のローカルリポジトリ特定ロジックは特定の環境向けに書かれています。自分の環境に合わせて `SKILL.md` の手順 1 を編集してください。**

## 使い方

Claude Code を自動承認モードで起動し、スキルを実行する:

```bash
claude --permission-mode acceptEdits
```

```
/dev-cross-review https://github.com/owner/repo/pull/123
```

## 出力

レビュー結果は以下に出力される:

- **ファイル**: `.code-reviews/{YYYYMMDD_HHMMSS}_{repo}_PR{番号}.md`
- **ターミナル**: サマリーテーブル（深刻度別の件数と主な指摘）

### 深刻度

| レベル | 意味 | 基準 |
|--------|------|------|
| CRITICAL | バグ | データ不整合、意図と異なる動作を引き起こすコード |
| WARNING | 潜在的な問題 | 正しく動くが壊れやすい設計/実装 |
| INFO | 改善の余地 | パフォーマンス、冗長コード、テスト不足 |

## ファイル構成

```
dev-cross-review/
├── SKILL.md                          # スキル定義（オーケストレーター）
└── agents/
    ├── claude-reviewer.md            # Claude エージェントのプロンプト
    └── codex-reviewer.md             # Codex エージェントのプロンプト
```
