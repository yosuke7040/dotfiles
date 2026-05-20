---
name: spec-driven-feature-dev
description: 要件と設計の合意を必須化した、仕様駆動の機能開発オーケストレーター（ハーネスエンジニアリングに基づく）。新機能の実装を依頼されたとき、設計から実装まで一気通貫で進めたいとき、要件が曖昧な段階から整理しつつ作り込みたいとき、Linear/GitHub Issue から機能開発を始めるときに使う。Phase 0 で Linear issue を確保（なければ作成）し、Codex主導で要件把握→設計検討→事前リファクタ判定→初回実装を行い、その後 Codexレビュー→Claudeトリアージ→修正→検証のループで品質を段階的に高める。事前リファクタが必要と判定された場合は、結合テスト追加 PR とリファクタ PR をマージしてから新機能ブランチを切る。収束後はリファクタリング観点とセキュリティ観点で専用レビューを1回ずつ行う（デフォルト有効・スキップ可）。「機能Xを実装したい」「設計から実装まで進めて」「新機能の開発を始めたい」「要件を整理しながら作りたい」などのフレーズで起動する。既に存在する差分への多段レビューにも応用可能だが、その場合でも要件と設計の合意を取り直してから進める。PR URL はベースブランチ推定にも使えるが、実際のレビュー対象は現在のローカル HEAD とする。
argument-hint: [Linear issue (HAN-123 or URL) | ベースブランチ | PR URL（省略時は main。PR URLはベースブランチ推定専用）]
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(date:*), Bash(mkdir:*), Bash(ls:*), Bash(rm:*), Bash(codex:*), Agent, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__list_teams, mcp__claude_ai_Linear__list_users, mcp__claude_ai_Linear__get_user, mcp__claude_ai_Linear__list_issue_statuses
---

# 仕様駆動 機能開発オーケストレーター

あなたは実装オーケストレーターとして、Codex主導の要件把握・設計検討・事前リファクタ判定と、Codexによるレビュー→Claudeによるトリアージ→修正→バリデーション→コミットのループを制御し、実装品質を段階的に高める。

## 設計思想（ハーネスエンジニアリング）

このワークフローは6つの原則に基づく:

- **明確化（Clarify）**: 実装前に要件と受け入れ条件を固定する
- **設計（Design）**: 既存コードベースに沿った実装方針を先に決める
- **制約（Constrain）**: Severityフィルタとdirectiveでレビューの過剰指摘を抑制する
- **情報提供（Inform）**: コーディングガイドラインと合意済み設計を各エージェントに渡す
- **検証（Verify）**: 修正が根本原因に対処できているか確認する
- **修正（Correct）**: 不十分な修正を差し戻して再修正する

## 役割分担

| 役割 | 担当 | 理由 |
|------|------|------|
| 要件把握 | Codex (codex exec) | 仕様の抜け漏れと曖昧さの検出 |
| 設計検討 | Codex (codex exec) | 既存コードに沿った設計案の比較 |
| 事前リファクタ機会の検出 | Codex (codex exec) | 周辺コードの整理余地と新機能側の簡素化見積もり |
| 事前リファクタ採否 | ユーザー | スコープ判断と PR 分割の意思決定 |
| トリアージ / 合意形成 | オーケストレーター (Claude) | 横断的判断・スコープ管理 |
| 初回実装 / 修正 | サブエージェント (Claude) | コード変更の実行 |
| バリデーション | オーケストレーター (Claude) | メタレベルの品質検証 |

## 絶対ルール

- **Phase 0 で Linear issue を必ず確保する**。引数 / ブランチ名 / ユーザー確認のいずれかで既存 issue を特定し、無ければ新規作成する。issue が確定するまで以降のフェーズへ進まない
- **新規ブランチを切る場合は Linear issue の `branchName` を優先採用する**。既にブランチがあるが Linear identifier と紐付かない場合は警告のみで続行する
- **Phase 0 でのブランチ作成は遅延する**。現在ブランチが main でかつ新規にブランチを切る必要がある場合、`git switch -c` は Phase 3 判定後（事前リファクタなし時）または Phase 3 Step 6（事前リファクタあり時）まで実行しない。Phase 1 / Phase 2 / Phase 3 Step 1〜2 は read-only なので main 上で問題ない
- **Phase 1（要件把握）と Phase 2（設計検討）はスキップしてはならない**。ベースブランチに対する既存差分の有無に関わらず必ず実行する。既存実装がある場合も、合意済みの要件と設計が確定するまでレビューループに入ってはならない
- **Phase 1 と Phase 2 では実装しない**。この段階の仕事は要件明確化と設計検討だけ
- **Phase 3（事前リファクタ判定）はデフォルト実行**。`skip_pre_refactor = true` をユーザーが明示した場合のみスキップする
- **Phase 3 で事前リファクタを採用した場合、PR1（test）と PR2（refactor）のマージ完了を待ってから Phase 4 に進む**。マージ前に Phase 4 を開始してはならない
- **事前リファクタは振る舞いを変えてはならない**。Step 4 で追加した結合テストが緑であることを Validate の必須条件とする
- **事前リファクタの対象は「既存コード」のみ**。新機能で初めて触るコードへのリファクタは Phase 5 Refactor Review の領分
- **要件が曖昧、または設計案が複数あって決め切れない場合は必ずユーザー確認を取る**。未確定のまま実装に進まない
- **オーケストレーターはレビューもコード変更もしない**。Codexにレビューさせ、実装・修正は修正エージェントに委譲する
- **`/dev-journal` を併用し、要件・設計判断・主要アクションを都度記録する**
- **各イテレーションの終了時に `dev-journal` を更新する**。指摘件数、採否判断、修正内容、directive、テスト結果、残課題を必ず残す
- **最大6イテレーション**。通常2-3回で収束する。6回到達時は残存指摘を報告して終了する
- **オシレーション検出時はdirectiveで固定**。A→B→Aの振り子パターンを検出したら、優れた方を選びdirectiveとして以降のイテレーションに強制適用する
- **Phase 5（Refactor Review）と Phase 6（Security Review）はデフォルト実行**。ユーザーが明示的に「skip refactor」「skip security」等を指定した場合のみスキップする。スキップ理由はジャーナルに記録する
- **Phase 6 で HIGH severity の脆弱性が残った場合、最終サマリーの先頭で必ず強調する**。ユーザーが見落とさないように扱う

## Codex 実行プロトコル（全 Phase 共通）

各 Phase で Codex を起動するときは、以下の共通手順に従う:

1. オーケストレーターは事前に `/tmp/task_context.md` と、必要なら `/tmp/review_diff.patch`（`git diff {ベースブランチ}...HEAD`）を準備する
2. Agent ツールで `general-purpose` サブエージェントを起動し、以下を委譲する:
   - プロンプトファイル（`prompts/{file}.md`）を Read する
   - プロンプト内のテンプレート変数（`{requirements_summary}` / `{design_summary}` / `{ガイドライン}` / `{directives}` 等）を、オーケストレーターから渡された実値で置換した完全プロンプトを作る
   - 以下のコマンドを `run_in_background: true` で起動する:

     ```bash
     REPO_ROOT=$(git rev-parse --show-toplevel)
     cat << 'PROMPT' | timeout 1200 codex exec --ephemeral -m gpt-5.5 -c model_reasoning_effort="xhigh" -s read-only -C "$REPO_ROOT" -o /tmp/codex_{name}.txt -
     {置換済みプロンプト本体}
     PROMPT
     ```

   - `BashOutput` で `[exit_code=0]` を確認してから `/tmp/codex_{name}.txt` を Read して返す
   - 結果が空または存在しない場合は同じコマンドを 1 回だけ再実行する。再実行でも結果が得られなければ「Codex が最終結果を返せなかった」と報告すること（自分で代替レビューはしない）
3. オーケストレーターは戻ってきた結果のみを次フェーズで利用する

> **重要**: background 起動なら Bash ツール呼び出しは起動直後に return するため、Bash ツールの `timeout` パラメータは実プロセスには効かない（デフォルトのままで問題ない）。実プロセスの時間上限は shell 側 `timeout 1200`（最大 20 分）で明示している。

---

## Phase 0: 準備・Linear issue 確保・ブランチ準備

**事前条件**: なし（スキル起動直後）

**この Phase の絶対ルール**:
- Linear issue を確保するまで先に進まない
- ブランチ作成は遅延（現在ブランチが main の場合は Phase 3 まで作成しない）

**成功条件**: `linear_issue` 確定 / `feature_branch_name`（必要なら `pre_refactor_branch_name` も）が予約済み / `/dev-journal` 開始

### 0-1. `$ARGUMENTS` 解析

優先順に判定する（複数該当しないように、最初にマッチしたものを採用）:

1. **Linear issue URL**（`https://linear.app/.../issue/{IDENT}-{N}` 形式）→ そこから `{IDENT}-{N}` を抽出して Linear issue として扱う
2. **Linear issue ID**（`[A-Z]+-\d+` 形式、例: `HAN-123`）→ そのまま Linear issue として扱う
3. **PR URL**（`https://github.com/owner/repo/pull/123` 形式）→ `gh pr view` でベースブランチを取得
4. **ブランチ名**（上記いずれにも該当しないトークン）→ 指定されたブランチをベースとする
5. **引数なし** → ベースブランチは `main`、Linear issue は未指定

PR URL を指定しても、このスキルがレビュー・修正対象とするのは **現在のローカル `HEAD`** である。
対象PRの差分を扱いたい場合は、先にそのPR相当のブランチをローカルで checkout しておくこと。

### 0-2. Linear issue の確保

このスキルでは「実装に紐付く Linear issue が必ず1つ存在する」前提を Phase 0 で確立する。確保ロジック:

1. **引数で Linear issue が指定された場合**: `mcp__claude_ai_Linear__get_issue` で取得し、`linear_issue` 状態に格納する
2. **指定がない場合、現在のブランチ名から推測**:
   - 現在のブランチ名に `[A-Z]+-\d+` パターンが含まれていれば、その ID を抽出して `get_issue` を試行
   - 取得できれば確定。取得失敗（404 等）した場合は次へ
3. **それでも確保できない場合、ユーザーに確認**:
   - 「既存の Linear issue がありますか？（あれば URL/ID を、なければ "create" と回答）」と聞く
   - 既存 issue 指定 → `get_issue` で取得
   - `create` → 0-3 へ

### 0-3. Linear issue の新規作成（必要な場合のみ）

ユーザーが新規作成を選んだ場合、最低限の情報で即作成する（詳細は Phase 1 完了後に追記する余地を残す）。

1. **タイトル**: ユーザーに「issue タイトルを1行で」と聞く
2. **チーム**: `mcp__claude_ai_Linear__list_teams` で取得し、
   - 1つしかなければ自動採用
   - 複数あればユーザーに選択させる
3. **状態**: `mcp__claude_ai_Linear__list_issue_statuses` から `In Progress` 相当の state を選ぶ（無ければデフォルトのまま）
4. **アサイン**: `mcp__claude_ai_Linear__get_user`（自分）でユーザーIDを取り、`assigneeId` に設定
5. **description**: `Spec-driven feature-dev で開発開始。要件・設計は Phase 1/2 完了後に追記する。` のプレースホルダ
6. `mcp__claude_ai_Linear__save_issue` で作成し、レスポンスから `id` / `identifier` / `url` / `branchName` / `title` を取得して `linear_issue` 状態に格納

### 0-4. ブランチ準備（遅延作成）

`linear_issue` が確定したあと:

1. **現在ブランチ != ベースブランチ**（既に作業ブランチがある）:
   - ブランチ名に `linear_issue.identifier` が含まれていれば紐付け OK、そのまま使用
   - 含まれていなければ警告を出すだけで続行（既存ブランチを尊重）
   - この場合は事前リファクタフェーズが採用された場合の挙動が複雑になる旨をユーザーに伝える（既存差分を待避してから事前リファクタブランチに移る必要がある）
2. **現在ブランチ == ベースブランチ**（新規にブランチを切る予定）:
   - `feature_branch_name` を確定する（`linear_issue.branchName` を優先、無ければ `{prefix}/{identifier-lowercase}-{title-slug}` 形式で生成。`prefix` は `git config user.name` のローマ字部分または `dev`、slug は英数とハイフンのみ・20文字程度に切り詰め）
   - `pre_refactor_branch_name` も予約だけしておく（`{prefix}/{identifier-lowercase}-pre-refactor`）
   - **ここでは `git switch -c` を実行しない**。実際の作成は Phase 3 完了後に行う

### 0-5. その他の準備

- `/dev-journal` が未実行なら先に実行し、ジャーナルを開始する。確保した `linear_issue` の `identifier` / `url` / `title` を作業ソースとして渡す
- プロジェクトのコーディングガイドラインを確認する（`CLAUDE.md`、`.eslintrc`、`pyproject.toml` の `[tool.ruff]` セクション等）
- 現時点の差分を `git diff {ベースブランチ}...HEAD` で確認し、存在する場合は後続フェーズの参考情報として保持する
- 差分の有無に関わらず Phase 1 / Phase 2 / Phase 3 は必ず実行する。既存差分は Phase 4 以降のレビュー対象として扱うが、要件と設計の合意を飛ばす根拠にはならない

```
━━━ spec-driven-feature-dev 開始 ━━━
Linear: {linear_issue.identifier} {linear_issue.title}
        {linear_issue.url}
ブランチ: {現在のブランチ} → {ベースブランチ}（feature ブランチは {feature_branch_name}、Phase 3 後に作成）
```

### 内部状態（全フェーズで保持）

- `linear_issue`: 確保した Linear issue（`id` / `identifier` / `title` / `url` / `branchName`）
- `feature_branch_name` / `pre_refactor_branch_name`: 予約済みブランチ名
- `requirements_summary` / `design_summary`: 合意済み要件・設計
- `iteration`: 現在のイテレーション番号（1始まり）
- `validate_retries`: 同一イテレーション内での Validate 差し戻し回数
- `history`: 各イテレーションの修正内容の要約（オシレーション検出用）
- `directives`: 固定された directive 一覧
- `total_findings` / `total_fixed`: レビューループの累計
- `refactor_findings` / `refactor_fixed`: Phase 5 集計
- `security_findings` / `security_fixed`: Phase 6 集計
- `pre_refactor_candidates`: Codex 抽出の事前リファクタ候補リスト
- `pre_refactor_adopted`: ユーザーが採用した候補
- `pre_refactor_test_pr_url` / `pre_refactor_refactor_pr_url`: PR 記録用
- `pre_refactor_status`: `pending` / `test_committed` / `refactor_committed` / `merged` / `skipped`
- `skip_pre_refactor` / `skip_refactor` / `skip_security`: 各フェーズをスキップするかのフラグ（ユーザーが明示した場合のみ true、デフォルト false）

---

## Phase 1: 要件把握（Codex主導 / 実装禁止）

**事前条件**: Phase 0 完了。`linear_issue` 確定済み

**この Phase の絶対ルール**:
- 実装やコード変更を行わない
- `Questions for User` にブロッカーがあれば必ずユーザー確認して停止する

**成功条件**: `requirements_summary` がユーザー承認込みで確定し、`/dev-journal` に記録される

### 手順

1. `/tmp/task_context.md` にユーザー依頼・Issue / PR情報・差分概要・ガイドラインパスを整理し、差分があれば `/tmp/review_diff.patch` に保存
2. 「Codex 実行プロトコル」に従い、`prompts/phase-1-requirements.md` を Codex に渡す（出力先: `/tmp/codex_requirements.txt`）
3. オーケストレーターは結果を受け取り:
   - `Questions for User` にブロッカーがあれば、ユーザーに確認して停止
   - ブロッカーがなければ `requirements_summary` として保持し、`/dev-journal` に記録

```
Requirements: {要点サマリー}
```

---

## Phase 2: 設計検討（Codex主導 / 実装禁止）

**事前条件**: Phase 1 完了。`requirements_summary` 確定済み

**この Phase の絶対ルール**:
- 実装やコード変更を行わない
- 合意済み要件に沿って既存コードベースと整合する設計を優先する
- `Open Questions` にブロッカーがあれば必ずユーザー確認して停止する

**成功条件**: `design_summary` がユーザー承認込みで確定し、`/dev-journal` に記録される

### 手順

1. 「Codex 実行プロトコル」に従い、`prompts/phase-2-design.md` を Codex に渡す（出力先: `/tmp/codex_design.txt`）。テンプレート変数 `{requirements_summary}` を実値で置換すること
2. オーケストレーターは結果を受け取り:
   - `Open Questions` にブロッカーがあれば、ユーザーに確認して停止
   - ブロッカーがなければ `design_summary` として保持し、`/dev-journal` に記録
   - 要件サマリーと設計案をユーザーに提示し、**承認を得るまで Phase 3 に進まない**

> **ユーザーレビュー**: 要件サマリーと設計案の承認を得てから次に進む

---

## Phase 3: 事前リファクタ判定・実施

**事前条件**: Phase 2 完了。`requirements_summary` / `design_summary` 確定済み

**この Phase の絶対ルール**:
- 事前リファクタは **既存コードのみ** が対象。新機能で初めて触るコードへのリファクタは Phase 5 Refactor Review の領分
- **振る舞いを変えてはならない**。Step 4 で追加する結合テストが緑であることを Validate の必須条件とする
- 採用した場合は PR1（test）と PR2（refactor）のマージ完了を待ってから Phase 4 に進む
- `skip_pre_refactor = true` がユーザーから事前指定されている場合は Step 0 で即時 Phase 4 へ

**成功条件**: `pre_refactor_status` が `merged` か `skipped` のいずれかに確定し、`/dev-journal` に記録される

### Step 0: 起動条件チェック

- `skip_pre_refactor = true` の場合: ジャーナルにスキップ理由を記録して **Phase 4 へ進む**
- そうでない場合は Step 1 へ

### Step 1: 事前リファクタ機会の検出（Codex / 実装禁止）

「Codex 実行プロトコル」に従い、`prompts/phase-3-pre-refactor.md` を Codex に渡す（出力先: `/tmp/codex_pre_refactor.txt`）。テンプレート変数 `{requirements_summary}` / `{design_summary}` を実値で置換する。

```
Pre-refactor Detection (Codex): {N}件の候補
```

**候補が 0 件の場合**: `skip_pre_refactor = true` 相当の状態として扱い、ジャーナルに記録して Phase 4 へ進む。

### Step 2: トリアージとユーザー承認

オーケストレーターが Codex の結果を読み、以下でフィルタ:

- 振る舞いを変えない候補のみ保持
- `design_summary` と矛盾する候補は除外
- スコープが大きすぎる候補（複数ファイル横断 / 高リスク）は「分割するか / 見送るか」をユーザーに確認

残った候補を番号付きでユーザーに提示し、`AskUserQuestion` で採否を選ばせる（`all` / `none` / `1,3,5` 相当の意味で）。

- `none` → `skip_pre_refactor = true` をジャーナルに記録して Phase 4 へ進む
- 採用候補あり → Step 3 へ

### Step 3: 事前リファクタ用ブランチ作成

- Phase 0 で `feature_branch_name` の作成を遅延しているため、現時点で現在ブランチは main のはず（既存作業ブランチがある場合は事前にユーザーと相談する旨を Phase 0 で警告済み）
- `git switch -c {pre_refactor_branch_name}` で main から派生
- `pre_refactor_status = pending` に設定

### Step 4: PR1 - テストカバレッジ追加（結合テスト中心）

Agent ツール（`general-purpose` サブエージェント）に修正タスクを委譲。プロンプト要点:

```text
以下の要件・設計と、採用された事前リファクタ候補に基づいて、リファクタの安全網となる
**結合テスト** を追加してください。

## Requirements
{requirements_summary}

## Design
{design_summary}

## 採用候補
{pre_refactor_adopted}

## 実装ルール
1. プロダクションコードには手を入れない（テスト追加のみ）
2. プロジェクト既存のテストインフラ（pytest / vitest / RSpec 等）に従う
3. **結合テスト優先**。各候補がカバーする振る舞いを結合テストで担保すること
4. ユニットテストは「結合テストだけでは特定の振る舞いを十分に固定できない」場合のみ補強
5. 追加したテストが全て通ることをローカル実行して確認する
6. テストの命名・配置は周辺の既存テストに合わせる
```

完了後、オーケストレーターが `git diff` を確認し、振る舞い変化（プロダクションコードの修正）が混入していないかチェックする。混入していたらサブエージェントに差し戻す。

PASS したらコミット: `test: cover {対象モジュール} behaviour before refactor ({linear_issue.identifier})`

`/dev-journal` 更新後、ユーザーに通知:

```
PR1 (test) 準備完了。
Push して PR を作成し、マージ後にスキルを再開してください。
ブランチ: {pre_refactor_branch_name}
```

`pre_refactor_status = test_committed` を設定して **スキルは一旦停止**。

### Step 5: PR2 - リファクタ実施

ユーザーが「再開」または `/spec-driven-feature-dev` を再起動した時点で実行する。

1. PR1 がマージ済みであることを確認: `git fetch && git log origin/main` で Step 4 の test コミットが main に取り込まれているか
2. `git switch main && git pull` で main 最新化
3. リファクタ用に `{pre_refactor_branch_name}-refactor` を main から派生（PR1 マージ済みの履歴と混同しないため別名）
4. Agent ツール（`general-purpose`）にリファクタタスクを委譲。プロンプト要点:

```text
以下の要件・設計と、Step 4 で追加した結合テストを安全網として、採用候補のリファクタを
実施してください。

## Requirements
{requirements_summary}

## Design
{design_summary}

## 採用候補
{pre_refactor_adopted}

## 実装ルール
1. 振る舞いを一切変えない（API シグネチャ・入出力・外部副作用の同一性を維持）
2. Step 4 のテストが通ることを確認する。通らなくなったら修正方針が間違っているので報告
3. 修正に自信がない場合は無理にやらず、その旨を報告する
4. テストやフォーマッタが存在する場合は実行して確認すること
```

完了後、オーケストレーターが `git diff` を確認し、振る舞い同一性を Validate（API シグネチャ、入出力、外部副作用が変わっていないか）。テスト緑も必須条件。

PASS したらコミット: `refactor: prepare for {linear_issue.identifier}`

`/dev-journal` 更新後、ユーザーに通知:

```
PR2 (refactor) 準備完了。
Push して PR を作成し、マージ後にスキルを再開してください。
ブランチ: {pre_refactor_branch_name}-refactor
```

`pre_refactor_status = refactor_committed` を設定して **スキルは一旦停止**。

### Step 6: feature ブランチ作成 → Phase 4 へ

ユーザー再開時:

1. PR2 マージ済みを確認: `git fetch && git log origin/main` で Step 5 の refactor コミットが main に取り込まれているか
2. `git switch main && git pull` で main 最新化
3. `git switch -c {feature_branch_name}` で feature ブランチを作成
4. `pre_refactor_status = merged` を記録
5. Phase 4（初回実装の有無確認）へ進む

### Step 7: Journal Update（各ステップ完了時に追記）

`/dev-journal` に以下を記録:

- Codex が提示した候補一覧と件数
- ユーザー採否（採用番号 / `none` / 全採用 等）
- PR1 / PR2 のブランチ名・コミットハッシュ・URL（記録できる範囲で）
- 追加したテストの件数・カバー範囲
- リファクタ箇所数と概要
- スキップした場合の理由

---

## Phase 4: 初回実装の有無確認

**事前条件**: Phase 3 完了。`pre_refactor_status` が `merged` または `skipped`。feature ブランチ作成済み（Phase 3 Step 6 で作成、または事前リファクタ skip 時は本フェーズ冒頭で作成）

**この Phase の絶対ルール**:
- `pre_refactor_status` が `test_committed` / `refactor_committed` のままなら、PR マージを待たずに進んではならない（Phase 3 に戻ってマージ確認を行う）
- 初回実装は合意済み要件・設計に厳密に従う

**成功条件**: feature ブランチ上に最低 1 つの差分が存在し、レビュー・修正ループに移行できる状態

### 手順

1. `pre_refactor_status` チェック:
   - `test_committed` / `refactor_committed` の場合 → ユーザーに PR マージ状況を確認し、Phase 3 の対応 Step に戻る
   - `merged` / `skipped` の場合 → 続行
2. 事前リファクタ skip かつ feature ブランチ未作成の場合は、ここで `git switch -c {feature_branch_name}` を実行（main から派生）
3. `git diff {ベースブランチ}...HEAD` に差分があるか確認:
   - **差分あり**: 既存の実装をそのままレビュー対象にしてレビュー・修正ループへ進む
   - **差分なし**: `design_summary` をもとに修正エージェントへ初回実装を委譲し、レビュー可能な最初の差分を作る

初回実装が必要な場合のプロンプト:

```text
以下の要件サマリーと設計案に基づいて、初回実装を行ってください。

## Requirements
{requirements_summary}

## Design
{design_summary}

## 実装ルール
1. 要件と設計に含まれない仕様を勝手に足さないこと
2. 既存コードのパターンとコーディングガイドラインに従うこと
3. テストやフォーマッタが存在する場合は実行して確認すること
4. 自信がない箇所は曖昧なまま実装せず、コメントで不足情報を残すこと
```

初回実装後、`git diff` が生成されたことを確認してからレビュー・修正ループへ進む。

---

## レビュー・修正ループ（最大6イテレーション）

**事前条件**: Phase 4 完了。feature ブランチ上に差分が存在

**この Phase の絶対ルール**:
- 1 イテレーションあたり 1 回の Codex レビューと、必要に応じて複数回の Validate 再修正（最大 3 回）
- オーケストレーターは直接コード編集してはならない
- オシレーション検出時は directive で固定して以降のイテレーションに強制適用

**成功条件**: findings 0 件で収束 / トリアージで全件除外 / 6 イテレーション到達 / blocked のいずれか

```
━━━ Iteration {N}/6 ━━━
```

各イテレーションの開始時に `validate_retries = 0` とする。

### Step 1: Review（Codex via サブエージェント）

「Codex 実行プロトコル」に従い、`prompts/loop-review.md` を Codex に渡す（出力先: `/tmp/codex_review.txt`）。テンプレート変数 `{requirements_summary}` / `{design_summary}` / `{directive一覧}` を実値で置換すること。

事前に差分を `/tmp/review_diff.patch` に保存しておく（`git diff {ベースブランチ}...HEAD > /tmp/review_diff.patch`）。

`total_findings += findings数`

```
Review (Codex): {N}件の指摘
```

**findings が 0 件の場合**: Step 6 でジャーナル更新を行ってからループを終了し、Phase 5 へ進む。

### Step 2: Triage（オーケストレーター自身が実施）

#### 2-1. Severity 分類
- CRITICAL / IMPORTANT → 修正対象として保持
- LOW → **除外**

#### 2-2. スコープ判定
各 finding が指摘するコードが、ベースブランチとの差分に含まれているか確認する。**変更していない既存コードへの指摘は除外する**。

判定方法: `git diff -U0 {ベースブランチ}...HEAD` の hunk から変更されたファイル・行範囲を取得し、finding のファイルパスと行番号がその範囲に含まれるかで判定。行番号がない場合はファイル単位で確認し、安易に除外しない。

#### 2-3. 合意済み要件・設計との整合確認
- 合意済みの設計判断を覆すだけの指摘は除外
- ただし、合意済み設計そのものに起因する明確なバグ指摘は保持

#### 2-4. オシレーション検出
`history` を参照し、以下のパターンを検出する:
- 前のイテレーションで修正したコードを「元に戻せ」という指摘
- A→B→A の振り子パターン

検出時:
1. A と B のどちらが優れているか判断
2. 優れた方を directive として `directives` に追加
3. 該当 finding を除外

```
Triage: CRITICAL {N} / IMPORTANT {N} / filtered {N}件除外
{directive追加があれば: "Directive追加: {内容}"}
```

**トリアージ後の findings が 0 件の場合**: Step 6 でジャーナル更新を行ってからループを終了し、Phase 5 へ進む。

### Step 3: Fix（サブエージェント）

Agent ツールで `general-purpose` を起動し、以下のプロンプトを渡す:

```text
以下のコードレビュー指摘に対して修正を実施してください。

## Requirements
{requirements_summary}

## Design
{design_summary}

{ガイドラインがある場合: "コーディングガイドライン: {パス一覧} を参照してください。"}

## Directives（従う義務あり）
{directivesがある場合はすべて列挙。ない場合は「なし」}

## 修正対象の Findings
{トリアージ後のfindings一覧}

## 修正ルール
1. 各 finding に対して根本原因を修正すること。表面的な対処（バンドエイド修正）は不可
2. Requirements / Design / Directive に矛盾する修正は行わないこと
3. 修正に自信がない場合は、修正せずにその旨をコメントで残すこと
4. テストやフォーマッタが存在する場合は実行して確認すること
5. レビュー指摘の "修正例" はあくまで参考。設計や周辺コードの整合性から外れている場合は、修正例に従わず自分の判断で根本原因に対処してよい（その旨をコミットメッセージか dev-journal に残す）
```

### Step 4: Validate（オーケストレーター自身が実施）

修正エージェントの結果を受け取った後、`git diff` で実際の変更内容を確認する。

#### 4-1. 要件・設計整合性
修正後の差分が `requirements_summary` / `design_summary` に沿っているか。

#### 4-2. 根本原因対処
各 finding に対する修正が根本原因に対処しているか。

#### 4-3. バンドエイド検出
- エラーを握りつぶしている（空の catch、無視）
- 条件分岐で問題のケースだけを回避している
- コメントアウトで対応している

#### 4-4. 新規問題の検出
修正が新たな問題を導入していないか。

不十分な修正がある場合:
1. 再修正ポイントを具体的に列挙
2. `validate_retries += 1`
3. `validate_retries < 3` なら、**同じイテレーションのまま** Step 3 に戻す。Step 1 Review には戻らず、iteration も増やさない
4. この分岐では Step 5 / Step 6 に進まず、Validate が PASS するまで Step 3 → Step 4 を繰り返す
5. `validate_retries >= 3` なら、そのイテレーションは `blocked` として Step 6 に記録したうえでループを終了し、最終サマリーで残存指摘として報告

オーケストレーター自身が直接コード編集してはならない。

Validate が PASS した場合は `validate_retries = 0` に戻す。

```
Validate: {PASS / 再修正 N件}
```

### Step 5: Commit

修正があり、Validate が PASS した場合:

1. `total_fixed += このイテレーションで PASS した finding 件数`
2. 修正内容を `history` に追加（オシレーション検出用）
3. 変更されたファイルをステージング
4. コミット: `fix: review remediation (iteration {N})`

```
Commit: {commit hash の先頭7文字}
```

修正がない場合はスキップ。

### Step 6: Journal Update

各イテレーションの終了時に `/dev-journal` へ少なくとも以下を追記:

- `iteration` 番号
- Codex レビュー件数と主要 finding
- トリアージで保持 / 除外した理由
- 追加または更新した `directives`
- 実施した修正の要約
- 実行したテスト / フォーマット / 検証結果
- コミット有無とコミットハッシュ
- 次イテレーションへの持ち越し事項

findings が 0 件で終了した場合や、トリアージで全件除外となった場合も、その判断理由をジャーナルに残してからループを抜ける。

**終了条件チェック**:
- `blocked` または unresolved 扱いになった場合 → ループ終了 → Phase 5 へ
- `iteration >= 6` → ループ終了 → Phase 5 へ
- それ以外 → `iteration++` して Step 1 へ

---

## Phase 5: Refactor Review（デフォルト有効・スキップ可）

**事前条件**: レビュー・修正ループ収束（findings 0 件 / トリアージで全件除外 / 6 イテレーション到達 / blocked）

**この Phase の絶対ルール**:
- バグ・要件逸脱は別フェーズの領分。本フェーズは品質観点のみ
- 機能の振る舞いを変える提案・修正は禁止
- `skip_refactor = true` の場合はスキップして Phase 6 へ

**成功条件**: 採用された refactor 指摘がすべて Validate PASS / または skip / または `none`

### Step 1: Refactor Review（Codex）

差分を `/tmp/review_diff.patch` に更新したうえで、「Codex 実行プロトコル」に従い `prompts/phase-5-refactor-review.md` を Codex に渡す（出力先: `/tmp/codex_refactor.txt`）。テンプレート変数 `{requirements_summary}` / `{design_summary}` を実値で置換する。

`refactor_findings += findings数`

```
Refactor Review (Codex): {N}件の指摘
```

findings が 0 件なら Phase 6 へ進む。

### Step 2: スコープ判定 + ユーザー選定

- ベースブランチ差分外への指摘は除外する（既存コードの大掃除はスコープ外）
- 残った指摘を番号付きでユーザーに提示する
- ユーザーが採用する番号を選ぶ（`all` / `none` / `1,3,5` 形式）
- `none` の場合は Phase 6 へ進む

### Step 3: Fix

採用された指摘のみを修正対象として `general-purpose` サブエージェントに修正させる。プロンプト要点:

- 機能の振る舞いを一切変えない
- 既存テストがあれば実行して合格を確認する
- 修正に自信がない場合は無理にやらず、その旨を報告する

### Step 4: Validate

`git diff` で実際の変更を確認し、以下をチェックする:

- 機能変化を起こしていないか（API シグネチャ、入出力、外部副作用の同一性）
- 既存テストが通っているか
- バンドエイドや握りつぶしがないか

不十分ならレビューループの Validate と同様に `validate_retries < 3` まで Step 3 に差し戻す。

### Step 5: Commit

PASS したら `refactor: post-implementation cleanup ({linear_issue.identifier})` でコミットし、`refactor_fixed` を更新する。

### Step 6: Journal Update

`/dev-journal` に Refactor Review の指摘件数・採用件数・修正サマリー・テスト結果を記録する。

---

## Phase 6: Security Review（デフォルト有効・スキップ可）

**事前条件**: Phase 5 完了またはスキップ

**この Phase の絶対ルール**:
- セキュリティ観点に集中。バグレビューと重なる部分も専用プロンプトで明示的に網羅する
- `skip_security = true` の場合はスキップして最終サマリーへ
- HIGH severity が残った場合は最終サマリー先頭で必ず強調する

**成功条件**: 採用された security 指摘がすべて Validate PASS / または skip / または `none`

### Step 1: Security Review（Codex）

差分を更新した `/tmp/review_diff.patch` を使用。「Codex 実行プロトコル」に従い `prompts/phase-6-security-review.md` を Codex に渡す（出力先: `/tmp/codex_security.txt`）。テンプレート変数 `{requirements_summary}` / `{design_summary}` を実値で置換する。

`security_findings += findings数`

```
Security Review (Codex): HIGH {N} / MEDIUM {N} / LOW {N}
```

### Step 2: Triage

- ベースブランチ差分外への指摘は除外（既存コードの脆弱性は本フェーズの守備範囲外。ただし HIGH は必ずユーザーに報告する）
- HIGH / MEDIUM は原則すべて修正対象。LOW はユーザー判断
- 要件・設計と矛盾する修正案（例: 機能要件として認証を意図的に外している場合など）は除外し、その旨を報告

### Step 3: Fix

採用された指摘について、`general-purpose` サブエージェントに修正させる。プロンプト要点:

- セキュリティ要件を満たしつつ、機能要件を壊さないこと
- 不確実な修正で見せかけの安全を作らないこと。修正の確証がなければユーザーにエスカレーションする
- 修正対象に依存ライブラリのアップデートが含まれる場合は、互換性も確認する

### Step 4: Validate

- 各 finding の脅威が実際に解消されているか（攻撃シナリオが成立しなくなっているか）
- 機能要件が壊れていないか
- 新たな脆弱性を導入していないか

不十分ならレビューループの Validate と同様に `validate_retries < 3` まで Step 3 に差し戻す。

### Step 5: Commit

PASS したら `security: address review findings ({linear_issue.identifier})` でコミットし、`security_fixed` を更新する。

### Step 6: Journal Update

`/dev-journal` に Security Review の指摘件数・severity 分布・採用件数・修正サマリーを記録する。HIGH が残った場合は必ず明記する。

---

## ループ終了後: 最終サマリー

```text
━━━ Review Complete ━━━
Linear: {linear_issue.identifier} {linear_issue.title} ({linear_issue.url})
Requirements: {要件サマリーの要点}
Design: {採用設計の要点}

Pre-refactor: {候補 N 件 / 採用 M 件}
              PR1 (test): {URL or branch}
              PR2 (refactor): {URL or branch}
              {skip 時: "skipped (reason: ...)"}

Iterations: {N}
Total findings: {累計指摘件数}
Fixed: {累計修正件数}
Directives: {固定された directive 件数}

Refactor: {refactor_findings 件指摘 / refactor_fixed 件修正}{skip 時: "skipped"}
Security: HIGH {N} / MEDIUM {N} / LOW {N} / fixed {N}{skip 時: "skipped"}

{残存指摘がある場合:
Remaining issues:
- [SEVERITY] {指摘タイトル} ({ファイル}) — {理由: 修正不能 / 6 イテレーション到達 / HIGH 残存等}
}
```

セキュリティ HIGH が残存している場合は、最終サマリー先頭で **強調表示** すること（ユーザーが見落とさないように）。
