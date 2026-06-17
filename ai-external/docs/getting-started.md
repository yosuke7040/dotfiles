# agent-skills の始め方

agent-skills は、Markdown 指示を受け取れる任意の AI コーディングエージェントで動作する。このガイドでは、汎用的な使い方を説明する。ツール固有の設定については、専用ガイドを参照する。

## スキルの仕組み

各スキルは、特定のエンジニアリングワークフローを説明する Markdown ファイル（`SKILL.md`）である。エージェントのコンテキストへ読み込まれると、エージェントは検証手順、避けるべきアンチパターン、終了条件を含むワークフローに従う。

**スキルは参照ドキュメントではない。** エージェントが従う段階的な手順である。

## クイックスタート（任意のエージェント）

### 1. リポジトリを clone する

```bash
git clone https://github.com/addyosmani/agent-skills.git
```

### 2. スキルを選ぶ

`skills/` ディレクトリを確認する。各サブディレクトリには、次を含む `SKILL.md` がある:
- **使う場面**: このスキルが適用されることを示すトリガー
- **プロセス**: 段階的なワークフロー
- **検証**: 作業完了を確認する方法
- **よくある正当化**: エージェントが手順を省くために使いがちな言い訳
- **危険信号**: スキルが破られている兆候

### 3. エージェントへスキルを読み込ませる

関連する `SKILL.md` の内容を、エージェントのシステムプロンプト、ルールファイル、または会話へコピーする。よく使われる方法は次のとおり:

**システムプロンプト:** セッション開始時にスキル内容を貼り付ける。

**ルールファイル:** プロジェクトのルールファイル（CLAUDE.md、.cursorrules など）へスキル内容を追加する。

**会話:** 指示時にスキルを参照する。例: 「この変更には test-driven-development プロセスに従ってください。」

### 4. 発見にはメタスキルを使う

`using-agent-skills` スキルを読み込んだ状態で始める。このスキルには、タスク種別を適切なスキルへ対応づけるフローチャートが含まれる。

## 推奨設定

### 最小構成（ここから始める）

次の 3 つの必須スキルをルールファイルへ読み込む:

1. **spec-driven-development**: 何を作るかを定義する
2. **test-driven-development**: 動くことを証明する
3. **code-review-and-quality**: マージ前に品質を検証する

この 3 つは、AI 支援開発で最も重要な品質ギャップをカバーする。

### ライフサイクル全体

包括的にカバーするには、フェーズごとにスキルを読み込む:

```
プロジェクト開始: spec-driven-development → planning-and-task-breakdown
開発中:           incremental-implementation + test-driven-development
マージ前:         code-review-and-quality + security-and-hardening
デプロイ前:       shipping-and-launch
```

### 文脈に応じた読み込み

すべてのスキルを一度に読み込まない。コンテキストを浪費する。現在のタスクに関連するスキルを読み込む:

- UI 作業中か。`frontend-ui-engineering` を読み込む
- デバッグ中か。`debugging-and-error-recovery` を読み込む
- CI 設定中か。`ci-cd-and-automation` を読み込む

## スキルの構造

すべてのスキルは同じ構造に従う:

```
YAML frontmatter（name、description）
├── 概要: このスキルが何をするか
├── 使う場面: トリガーと条件
├── 中核プロセス: 段階的なワークフロー
├── 例: コード例とパターン
├── よくある正当化: 言い訳と反論
├── 危険信号: スキルが破られている兆候
└── 検証: 終了条件チェックリスト
```

完全な仕様は [skill-anatomy.md](skill-anatomy.md) を参照する。

## エージェントの使用

`agents/` ディレクトリには、事前設定済みのエージェントペルソナが含まれる:

| エージェント | 目的 |
|--------------|------|
| `code-reviewer.md` | 5 軸コードレビュー |
| `test-engineer.md` | テスト戦略とテスト作成 |
| `security-auditor.md` | 脆弱性検出 |
| `web-performance-auditor.md` | Core Web Vitals と性能監査（`/webperf` 経由） |

専門的なレビューが必要なときにエージェント定義を読み込む。たとえば、コーディングエージェントへ「code-reviewer エージェントペルソナを使ってこの変更をレビューして」と依頼し、エージェント定義を提供する。

## コマンドの使用

`.claude/commands/` ディレクトリには Claude Code 用のスラッシュコマンドが含まれる:

| コマンド | 起動されるスキル |
|----------|------------------|
| `/spec` | spec-driven-development |
| `/plan` | planning-and-task-breakdown |
| `/build` | incremental-implementation + test-driven-development |
| `/build auto` | planning-and-task-breakdown → incremental-implementation + test-driven-development（計画全体、1 回の承認） |
| `/test` | test-driven-development |
| `/review` | code-review-and-quality |
| `/code-simplify` | code-simplification |
| `/ship` | shipping-and-launch |
| `/webperf` | web-performance-auditor（専門エージェント、Web アプリのみ） |

## 参照資料の使用

`references/` ディレクトリには補助チェックリストが含まれる:

| 参照資料 | 併用するもの |
|----------|--------------|
| `testing-patterns.md` | test-driven-development |
| `performance-checklist.md` | performance-optimization |
| `security-checklist.md` | security-and-hardening |
| `accessibility-checklist.md` | frontend-ui-engineering |

スキルが扱う範囲を超えた詳細パターンが必要なとき、参照資料を読み込む。

## 仕様とタスク成果物

`/spec` と `/plan` コマンドは作業成果物（`SPEC.md`、`tasks/plan.md`、`tasks/todo.md`）を作る。作業中はこれらを **生きた文書** として扱う:

- 開発中はバージョン管理に入れ、人間とエージェントが共有する信頼できる情報源にする。
- スコープや判断が変わったら更新する。
- リポジトリでこれらのファイルを長期的に残したくない場合は、マージ前に削除するか、フォルダを `.gitignore` へ追加する。このワークフローは、それらが永続的であることを要求しない。

## ヒント

1. 自明でない作業では **spec-driven-development** から始める
2. コードを書くときは **test-driven-development** を必ず読み込む
3. **検証手順を省かない**。そこが要点である
4. **スキルは選択的に読み込む**。コンテキストが多いほど良いとは限らない
5. **レビューにはエージェントを使う**。異なる視点は異なる問題を見つける
