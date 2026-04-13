---
name: dev-journal
description: 機能開発・不具合調査・設計検討時に、意思決定と実施内容をリアルタイムで記録するスキル。Linear、GitHub Issue、直接依頼に対応し、作業開始時にジャーナルを作成して都度追記する。
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(gh:*), Bash(date:*), Bash(mkdir:*), Bash(ls:*)
---

# 開発ジャーナル（dev-journal）スキル

機能開発、設計検討、不具合調査、コードレビュー対応の開始時に、作業の根拠と実施内容を継続記録する。
コンテキストウィンドウの圧縮や途中中断があっても、判断理由と進捗を追跡できる状態を保つ。

## 適用条件

このスキルは次のいずれかに該当する場合に使う:

- 3ステップ以上の作業
- 設計判断やトレードオフが発生する作業
- Linear / GitHub Issue / PRコメント起点の作業
- 後で「なぜそうしたか」を残しておきたい作業

typo修正など一瞬で終わる作業では省略してよい。

## スキル起動時の動作

`/dev-journal` が実行されたら、以下の手順で動作する。

### 1. 作業ソースの特定

作業の起点を次から1つ選ぶ:

- **Linear**: チケットID、URL、タイトル
- **GitHub Issue**: URL または `owner/repo#123`
- **Direct Request**: ユーザーからの直接依頼。Issueやチケットがない場合

GitHub Issue が指定されていて `gh` で取得可能な場合は、`gh issue view` で `title` / `body` / `url` を取得して記録に使う。
Linear は専用ツールがない前提で、ユーザー提供情報をそのまま使う。

### 2. 基本情報の確認

最低限、以下を記録する:

- **作業名**（英語、ケバブケース）
- **作業ソース**
- **ソースID / URL**
- **ソースタイトル**
- **現在ブランチ**
- **ベースブランチ**（分かる場合）
- **開始時点の目的**
- **既知の要件 / 受け入れ条件**
- **未解決の不明点**

### 3. ジャーナルファイルの作成

- `docs/dev-journal/` ディレクトリが存在しなければ作成
- `docs/dev-journal/YYYY-MM-DD-HH-MM_task-name.md` を作成
- タイムスタンプはローカル時刻を使う

### 4. 作業開始

ジャーナル作成後、通常の作業を開始する。
以後は「追記ルール」に従って、判断・調査・実装・テスト・対話の都度追記する。

---

## ジャーナルテンプレート

```markdown
# {作業名}

- 開始日時: YYYY-MM-DD HH:MM
- ステータス: in_progress
- 作業ソース: Linear | GitHub Issue | Direct Request
- ソースID: {チケットID or issue番号 or none}
- ソースURL: {URL or none}
- ソースタイトル: {タイトル or none}
- 現在ブランチ: {branch}
- ベースブランチ: {base branch or unknown}

## Objective

{この作業で達成したいこと}

## Requirement Snapshot

- In scope:
- Out of scope:
- Acceptance criteria:
- Unknowns / assumptions:

## Work Log

- YYYY-MM-DD HH:MM - 作業開始。{初期状況}

## Investigations

- YYYY-MM-DD HH:MM - {調査した対象}: {分かったこと}

## Decisions

- YYYY-MM-DD HH:MM - {決定内容}
  理由: {なぜその判断にしたか}
  代替案: {捨てた案があれば}

## Changed Files

- {path}: {変更理由}

## Risks / Constraints

- {制約、既知リスク、依存関係}

## Open Questions

- {未解決事項}

## Next Actions

- {次にやること}

## Completion

- 終了日時:
- 最終ステータス: done | blocked | paused
- 概要:
```

---

## 追記ルール

作業中の判断やアクションが発生するたびに、以下のルールでジャーナルに追記する。

### 必ず追記するタイミング

- **既存コードを読んだとき**: 何を参照し、どのパターンを踏襲するか
- **要件を解釈したとき**: In scope / Out of scope / Acceptance criteria の更新
- **設計判断をしたとき**: 採用案と不採用案、その理由
- **レビュー / 修正ループの各イテレーション終了時**: 指摘件数、採否判断、修正内容、directive、テスト結果、残課題を記録する
- **ファイルを変更したとき**: 何を変えたか、なぜ変えたか
- **テストやLintを実行したとき**: 実行コマンド、結果、次の判断
- **問題が起きたとき**: 事実、仮説、解決策、未解決なら次の打ち手
- **ユーザーから追加指示が出たとき**: 要件変更や承認内容
- **タスク完了 / 中断時**: 現在地、残件、再開条件

### 記録のしかた

- 事実と仮説を混同しない
- 「何をしたか」だけでなく「なぜそうしたか」まで記録する
- 変更ファイル一覧は最後にまとめて書かず、増えるたびに更新する
- 新しい要件や制約が分かったら `Requirement Snapshot` を更新する
- 反復型ワークフローでは「1ループ = 1ログエントリ」を基本とし、その周回での判断を要約する
- 後でまとめて書くのではなく、その場で追記する

### 完了時の処理

- `ステータス` を `done` / `blocked` / `paused` のいずれかに更新する
- `Completion` を埋める
- `Changed Files`、`Risks / Constraints`、`Open Questions` を最終状態に更新する

このスキルは実装を進めるためのものではなく、判断と作業履歴を失わないための土台として使う。
