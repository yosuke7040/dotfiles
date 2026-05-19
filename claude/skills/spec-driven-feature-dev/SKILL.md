---
name: spec-driven-feature-dev
description: 要件と設計の合意を必須化した、仕様駆動の機能開発オーケストレーター（ハーネスエンジニアリングに基づく）。新機能の実装を依頼されたとき、設計から実装まで一気通貫で進めたいとき、要件が曖昧な段階から整理しつつ作り込みたいとき、Linear/GitHub Issue から機能開発を始めるときに使う。Phase 0 で Linear issue を確保（なければ作成）してからブランチを切り、Codex主導で要件把握→設計検討→初回実装を行い、その後 Codexレビュー→Claudeトリアージ→修正→検証のループで品質を段階的に高める。収束後はリファクタリング観点とセキュリティ観点で専用レビューを1回ずつ行う（デフォルト有効・スキップ可）。「機能Xを実装したい」「設計から実装まで進めて」「新機能の開発を始めたい」「要件を整理しながら作りたい」などのフレーズで起動する。既に存在する差分への多段レビューにも応用可能だが、その場合でも要件と設計の合意を取り直してから進める。PR URL はベースブランチ推定にも使えるが、実際のレビュー対象は現在のローカル HEAD とする。
argument-hint: [Linear issue (HAN-123 or URL) | ベースブランチ | PR URL（省略時は main。PR URLはベースブランチ推定専用）]
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(date:*), Bash(mkdir:*), Bash(ls:*), Bash(rm:*), Bash(codex:*), Agent, mcp__claude_ai_Linear__get_issue, mcp__claude_ai_Linear__save_issue, mcp__claude_ai_Linear__list_teams, mcp__claude_ai_Linear__list_users, mcp__claude_ai_Linear__get_user, mcp__claude_ai_Linear__list_issue_statuses
---

# 仕様駆動 機能開発オーケストレーター

あなたは実装オーケストレーターとして、Codex主導の要件把握・設計検討と、Codexによるレビュー→Claudeによるトリアージ→修正→バリデーション→コミットのループを制御し、実装品質を段階的に高める。

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
| トリアージ / 合意形成 | オーケストレーター (Claude) | 横断的判断・スコープ管理 |
| 初回実装 / 修正 | サブエージェント (Claude) | コード変更の実行 |
| バリデーション | オーケストレーター (Claude) | メタレベルの品質検証 |

## 絶対ルール

- **Phase 0 で Linear issue を必ず確保する**。引数 / ブランチ名 / ユーザー確認のいずれかで既存 issue を特定し、無ければ新規作成する。issue が確定するまで以降のフェーズへ進まない
- **新規ブランチを切る場合は Linear issue の `branchName` を優先採用する**。既にブランチがあるが Linear identifier と紐付かない場合は警告のみで続行する
- **Phase 1（要件把握）と Phase 2（設計検討）はスキップしてはならない**。ベースブランチに対する既存差分の有無に関わらず必ず実行する。既存実装がある場合も、合意済みの要件と設計が確定するまでレビューループに入ってはならない
- **Phase 1とPhase 2では実装しない**。この段階の仕事は要件明確化と設計検討だけ
- **要件が曖昧、または設計案が複数あって決め切れない場合は必ずユーザー確認を取る**。未確定のまま実装に進まない
- **オーケストレーターはレビューもコード変更もしない**。Codexにレビューさせ、実装・修正は修正エージェントに委譲する
- **`/dev-journal` を併用し、要件・設計判断・主要アクションを都度記録する**
- **各イテレーションの終了時に `dev-journal` を更新する**。指摘件数、採否判断、修正内容、directive、テスト結果、残課題を必ず残す
- **最大6イテレーション**。通常2-3回で収束する。6回到達時は残存指摘を報告して終了する
- **オシレーション検出時はdirectiveで固定**。A→B→Aの振り子パターンを検出したら、優れた方を選びdirectiveとして以降のイテレーションに強制適用する
- **Phase 4（Refactor Review）と Phase 5（Security Review）はデフォルト実行**。ユーザーが明示的に「skip refactor」「skip security」等を指定した場合のみスキップする。スキップ理由はジャーナルに記録する
- **Phase 5 で HIGH severity の脆弱性が残った場合、最終サマリーの先頭で必ず強調する**。ユーザーが見落とさないように扱う

---

## Phase 0: 準備・Linear issue 確保・ブランチ作成

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

### 0-4. ブランチ作成

`linear_issue` が確定したあと:

1. **現在ブランチ != ベースブランチ**（既に作業ブランチがある）:
   - ブランチ名に `linear_issue.identifier` が含まれていれば紐付け OK、そのまま使用
   - 含まれていなければ警告を出すだけで続行（既存ブランチを尊重）
2. **現在ブランチ == ベースブランチ**（新規にブランチを切る）:
   - `linear_issue.branchName` があれば優先採用（Linear が返す suggested branch name）
   - 無ければ `{git config user.name のローマ字部分 or "dev"}/{identifier-lowercase}-{title-slug}` の形式で生成（slug は英数とハイフンのみ、20文字程度に切り詰め）
   - `git switch -c {branchName}` で作成

### 0-5. その他の準備

- `/dev-journal` が未実行なら先に実行し、ジャーナルを開始する。確保した `linear_issue` の `identifier` / `url` / `title` を作業ソースとして渡す
- プロジェクトのコーディングガイドラインを確認する（`CLAUDE.md`、`.eslintrc`、`pyproject.toml` の `[tool.ruff]` セクション等）
- 現時点の差分を `git diff {ベースブランチ}...HEAD` で確認し、存在する場合は後続フェーズの参考情報として保持する
- 差分の有無に関わらず Phase 1 / Phase 2 は必ず実行する。既存差分は Phase 3 以降のレビュー対象として扱うが、要件と設計の合意を飛ばす根拠にはならない

```
━━━ spec-driven-feature-dev 開始 ━━━
Linear: {linear_issue.identifier} {linear_issue.title}
        {linear_issue.url}
ブランチ: {現在のブランチ} → {ベースブランチ}
```

### イテレーション管理用の内部状態

以下をフェーズ間・イテレーション間で保持する:

- `linear_issue`: 確保した Linear issue の情報（`id` / `identifier` / `title` / `url` / `branchName`）
- `requirements_summary`: 合意済みの要件サマリー
- `design_summary`: 合意済みの設計サマリー
- `iteration`: 現在のイテレーション番号（1始まり）
- `validate_retries`: 同一イテレーション内でのValidate差し戻し回数
- `history`: 各イテレーションの修正内容の要約（オシレーション検出用）
- `directives`: 固定されたdirective一覧
- `total_findings`: 累計指摘件数
- `total_fixed`: 累計修正件数
- `refactor_findings` / `refactor_fixed`: Phase 4（リファクタ）の集計
- `security_findings` / `security_fixed`: Phase 5（セキュリティ）の集計
- `skip_refactor` / `skip_security`: 各フェーズをスキップするかのフラグ（ユーザーが明示した場合のみ true、デフォルト false）

---

## Phase 1: 要件把握（Codex主導 / 実装禁止）

Agentツールで `general-purpose` サブエージェントを起動し、その中で `codex exec` を実行させる。

オーケストレーターは事前に、ユーザー依頼・Issue / PR情報・差分概要・ガイドラインパスを `/tmp/task_context.md` に整理して渡す。
差分がある場合は `/tmp/review_diff.patch` に保存する。

サブエージェントへのプロンプト:

```text
以下のコマンドでCodexに要件整理を実行させ、結果を返してください。
あなた自身は要件整理を行わず、Codexの結果をそのまま返すことだけが仕事です。

前提:
- 実装やコード変更は行わないこと
- 必要ならワーキングディレクトリ内の関連コードを読んでよい

Codexには以下を渡してください:
- タスクコンテキスト: /tmp/task_context.md
- 差分ファイル（存在する場合）: /tmp/review_diff.patch

最初にリポジトリルートを取得してください:

REPO_ROOT=$(git rev-parse --show-toplevel)

Codex は **Bash ツールの `run_in_background: true` で起動**し、`BashOutput` で `[exit_code=0]` を確認してから結果ファイルを読むこと。background 起動なら Bash ツール呼び出しは起動直後に return するため、Bash ツールの `timeout` パラメータは実プロセスには効かない（デフォルトのままで問題ない）。実プロセスの時間上限は shell 側 `timeout 1200`（= 最大20分）で明示している:

cat << 'PROMPT' | timeout 1200 codex exec --ephemeral -m gpt-5.5 -c model_reasoning_effort="xhigh" -s read-only -C "$REPO_ROOT" -o /tmp/codex_requirements.txt -
あなたは要件整理担当です。実装やコード変更は行わないでください。

入力コンテキスト:
- タスク情報: /tmp/task_context.md
- 差分ファイル（存在する場合）: /tmp/review_diff.patch

{ガイドラインがある場合: "以下のコーディングガイドラインも参照してください: {パス一覧}"}

以下の形式で出力してください:

## Objective
## In Scope
## Out of Scope
## Acceptance Criteria
## Affected Areas
## Unknowns / Assumptions
## Questions for User

要件が曖昧な場合は、曖昧な点を推測で埋めずに `Questions for User` に列挙してください。

Do not hedge or seek confirmation in the analysis itself. State concrete findings, gaps, and a recommended choice. Use the dedicated "Questions for User" section only when user input is genuinely required to proceed; do not insert generic clarifications.
PROMPT

`BashOutput` で完了確認後、Read で /tmp/codex_requirements.txt を取得して返すこと。
```

オーケストレーターは結果を受け取り、以下を行う:

- `Questions for User` にブロッカーがある場合は、ユーザーに確認して停止する
- ブロッカーがない場合は `requirements_summary` として保持し、`/dev-journal` に記録する

```
Requirements: {要点サマリー}
```

---

## Phase 2: 設計検討（Codex主導 / 実装禁止）

Phase 1 の `requirements_summary` をもとに、再度Agentツールで `general-purpose` サブエージェントを起動し、その中で `codex exec` を実行させる。

サブエージェントへのプロンプト:

```text
以下のコマンドでCodexに設計検討を実行させ、結果を返してください。
あなた自身は設計を行わず、Codexの結果をそのまま返すことだけが仕事です。

前提:
- 実装やコード変更は行わないこと
- 必要なら関連コードや既存パターンを読むこと
- 合意済み要件に沿って、既存コードベースと整合する設計を優先すること

最初にリポジトリルートを取得してください:

REPO_ROOT=$(git rev-parse --show-toplevel)

Codex は **Bash ツールの `run_in_background: true` で起動**し、`BashOutput` で `[exit_code=0]` を確認してから結果ファイルを読むこと（最大20分）:

cat << 'PROMPT' | timeout 1200 codex exec --ephemeral -m gpt-5.5 -c model_reasoning_effort="xhigh" -s read-only -C "$REPO_ROOT" -o /tmp/codex_design.txt -
あなたは設計検討担当です。実装やコード変更は行わないでください。

入力:
- 要件サマリー: {requirements_summary}
- タスク情報: /tmp/task_context.md
- 差分ファイル（存在する場合）: /tmp/review_diff.patch

{ガイドラインがある場合: "以下のコーディングガイドラインも参照してください: {パス一覧}"}

以下の形式で出力してください:

## Recommended Design
## Files / Modules To Change
## Data / API / State Impact
## Risks / Tradeoffs
## Test Strategy
## Rejected Alternatives
## Open Questions

複数案がある場合は、最有力案を1つ選んだうえで代替案を `Rejected Alternatives` に整理してください。
判断に必要な追加確認がある場合のみ `Open Questions` に列挙してください。

Do not hedge or seek confirmation in the analysis itself. State concrete findings, gaps, and a recommended choice. Use the dedicated "Open Questions" section only when user input is genuinely required to proceed; do not insert generic clarifications.
PROMPT

`BashOutput` で完了確認後、Read で /tmp/codex_design.txt を取得して返すこと。
```

オーケストレーターは結果を受け取り、以下を行う:

- `Open Questions` にブロッカーがある場合は、ユーザーに確認して停止する
- ブロッカーがない場合は `design_summary` として保持し、`/dev-journal` に記録する
- 要件サマリーと設計案をユーザーに提示し、承認を得るまで次に進まない

> **ユーザーレビュー**: 要件サマリーと設計案の承認を得てから次に進む

---

## Phase 3: 初回実装の有無確認

Phase 1 / Phase 2 が完了し、`requirements_summary` と `design_summary` が確定していることを前提とする。

`git diff {ベースブランチ}...HEAD` に差分があるか確認する。

- **差分あり**: 既存の実装をそのままレビュー対象にする
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

## レビュー・修正ループ開始（最大6イテレーション）

```
━━━ Iteration {N}/6 ━━━
```

各イテレーションの開始時に `validate_retries = 0` とする。

---

### Step 1: Review（Codex via サブエージェント）

Agentツールで `general-purpose` サブエージェントを起動し、その中で `codex exec` を実行させる。

サブエージェントへのプロンプト:

```text
以下のコマンドでCodexにコードレビューを実行させ、結果を返してください。
あなた自身はレビューを行わず、Codexの結果をそのまま返すことだけが仕事です。

まず差分を一時ファイルに保存し、リポジトリルートを取得してください:
git diff {ベースブランチ}...HEAD > /tmp/review_diff.patch
REPO_ROOT=$(git rev-parse --show-toplevel)

次に以下のコマンドでCodexを実行してください。Bash ツールは **`run_in_background: true` で起動**し、`BashOutput` で `[exit_code=0]` を確認してから結果ファイルを読むこと。background 起動なら Bash ツール呼び出しは起動直後に return するため、Bash ツールの `timeout` パラメータは実プロセスには効かない（デフォルトのままで問題ない）。実プロセスの時間上限は shell 側 `timeout 1200`（= 最大20分）で明示している:

cat << 'PROMPT' | timeout 1200 codex exec --ephemeral -m gpt-5.5 -c model_reasoning_effort="xhigh" -s read-only -C "$REPO_ROOT" -o /tmp/codex_review.txt -
以下のgit差分をレビューし、バグや設計上の問題、潜在的問題を見つけてください。

差分ファイル: /tmp/review_diff.patch
合意済み要件: {requirements_summary}
合意済み設計: {design_summary}

{ガイドラインがある場合: "以下のコーディングガイドラインも参照してください: {パス一覧}"}

{directivesがある場合: "
以下のdirectiveは過去のイテレーションで確定済みです。これらに矛盾する指摘は行わないでください:
{directive一覧}
"}

各指摘は以下のフォーマットで出力してください:

### [SEVERITY] 指摘タイトル
- **ファイル**: `ファイルパス:行番号`
- **問題**: 何が問題か
- **根拠**: なぜ問題と判断したか
- **修正方針**: どう修正すべきか(短文で方針を述べる)
- **修正例**: before/after の差分を Markdown コードブロック(diff 形式推奨)で示す。**CRITICAL / IMPORTANT は必須**。書き直し規模が大きく示しきれない場合のみ `(方針のみ)` で省略可。LOW は任意

修正例のテンプレート:

```diff
- old_code
+ new_code
```

抽象的なアドバイス("検討すべき"・"考慮するとよい")で終わらせない。修正エージェントが手を動かせるレベルまで具体化すること。

SEVERITYは以下のいずれか:
- CRITICAL: バグ、データ不整合、意図と異なる動作、要件逸脱
- IMPORTANT: 潜在的問題、特定条件で壊れやすい設計、設計逸脱
- LOW: スタイル、パフォーマンス微改善、冗長コード

偽陽性よりも偽陰性を避けることを優先してください。怪しいものは指摘し、判断はトリアージに委ねてください。
差分だけでは判断できない場合は、ワーキングディレクトリの周辺コードも参照してください。

No confirmations or questions are needed. Proactively provide concrete proposals, fixes, and code examples.
PROMPT

`BashOutput` で完了確認後、Read で /tmp/codex_review.txt を取得して返すこと。

Codexが結果を返さなかった場合（ファイルが空や存在しない場合）は、同じコマンドを1回だけ再実行してください。
再実行でも結果が得られない場合は「Codexが最終結果を返せなかった」と報告してください。自分で代替レビューを行わないこと。
```

レビュー結果を受け取り、件数を記録する。

- `total_findings += findings数`

```
Review (Codex): {N}件の指摘
```

**findingsが0件の場合**: Step 6 でジャーナル更新を行ってからループを終了し、Phase 4 へ進む。

---

### Step 2: Triage（オーケストレーター自身が実施）

レビュー結果に対して以下のフィルタリングを順に適用する:

#### 2-1. Severity分類

各findingのSEVERITYを確認し、以下のように処理:

- **CRITICAL**: 修正対象として保持
- **IMPORTANT**: 修正対象として保持
- **LOW**: **除外**

#### 2-2. スコープ判定

各findingが指摘するコードが、ベースブランチとの差分に含まれているか確認する。**変更していない既存コードへの指摘は除外する**。

判定方法: `git diff -U0 {ベースブランチ}...HEAD` の hunk から変更されたファイル・行範囲を取得し、finding のファイルパスと行番号がその範囲に含まれるかで判定する。
finding に行番号がない場合はファイル単位で確認し、安易に除外しない。

#### 2-3. 合意済み要件・設計との整合確認

各findingが `requirements_summary` / `design_summary` / `directives` に矛盾しないか確認する。

- 合意済みの設計判断を覆すだけの指摘は除外する
- ただし、合意済み設計そのものに起因する明確なバグ指摘は保持する

#### 2-4. オシレーション検出

`history` を参照し、以下のパターンを検出する:

- 前のイテレーションで修正したコードを「元に戻せ」という指摘
- A→B→Aの振り子パターン

検出した場合:

1. AとBのどちらが優れているか判断する
2. 優れた方をdirectiveとして `directives` に追加する
3. 該当findingを除外する

```
Triage: CRITICAL {N} / IMPORTANT {N} / filtered {N}件除外
{directive追加があれば: "Directive追加: {内容}"}
```

**トリアージ後のfindingsが0件の場合**: Step 6 でジャーナル更新を行ってからループを終了し、Phase 4 へ進む。

---

### Step 3: Fix（サブエージェント）

Agentツールで `general-purpose` を起動する。

プロンプト:

```text
以下のコードレビュー指摘に対して修正を実施してください。

## Requirements
{requirements_summary}

## Design
{design_summary}

{ガイドラインがある場合: "コーディングガイドライン: {パス一覧} を参照してください。"}

## Directives（従う義務あり）
{directivesがある場合はすべて列挙。ない場合は「なし」}

## 修正対象のFindings
{トリアージ後のfindings一覧}

## 修正ルール
1. 各findingに対して根本原因を修正すること。表面的な対処（バンドエイド修正）は不可
2. Requirements / Design / Directive に矛盾する修正は行わないこと
3. 修正に自信がない場合は、修正せずにその旨をコメントで残すこと
4. テストやフォーマッタが存在する場合は実行して確認すること
5. レビュー指摘の "修正例" はあくまで参考。設計や周辺コードの整合性から外れている場合は、修正例に従わず自分の判断で根本原因に対処してよい（その旨をコミットメッセージか dev-journal に残す）
```

---

### Step 4: Validate（オーケストレーター自身が実施）

修正エージェントの結果を受け取った後、`git diff` で実際の変更内容を確認する。

以下のチェックを実施する:

#### 4-1. 要件・設計整合性の確認
修正後の差分が `requirements_summary` と `design_summary` に沿っているか確認する。

#### 4-2. 根本原因対処の確認
各findingに対する修正が、根本原因に対処しているかを確認する。

#### 4-3. バンドエイド修正の検出
以下のパターンはバンドエイド修正とみなす:

- エラーを握りつぶしている（空のcatch, 無視）
- 条件分岐で問題のケースだけを回避している
- コメントアウトで対応している

#### 4-4. 新規問題の検出
修正が新たな問題を導入していないか確認する。

不十分な修正がある場合:

1. 再修正ポイントを具体的に列挙する
2. `validate_retries += 1` とする
3. `validate_retries < 3` なら、**同じイテレーションのまま** Step 3 に戻して再修正させる
4. Step 1 Review には戻らない。iteration も増やさない
5. この分岐では Step 5 / Step 6 に進まず、Validate が PASS するまで Step 3 → Step 4 を繰り返す
6. `validate_retries >= 3` なら、そのiterationは `blocked` として Step 6 に記録したうえでループを終了し、最終サマリーで残存指摘として報告する

オーケストレーター自身が直接コード編集してはならない。

Validate が PASS した場合は `validate_retries = 0` に戻す。

```
Validate: {PASS / 再修正 N件}
```

---

### Step 5: Commit

修正があり、ValidateがPASSした場合:

1. `total_fixed += このイテレーションでValidate PASSしたfinding件数`
2. 修正内容を `history` に追加（オシレーション検出用）
3. 変更されたファイルをステージング
4. コミット: `fix: review remediation (iteration {N})`

```
Commit: {commit hash の先頭7文字}
```

修正がない場合はスキップする。

### Step 6: Journal Update

各イテレーションの終了時に、`/dev-journal` へ少なくとも以下を追記する:

- `iteration` 番号
- Codexレビュー件数と主要finding
- トリアージで保持 / 除外した理由
- 追加または更新した `directives`
- 実施した修正の要約
- 実行したテスト / フォーマット / 検証結果
- コミット有無とコミットハッシュ
- 次イテレーションへの持ち越し事項

findings が0件で終了した場合や、トリアージで全件除外となった場合も、その判断理由をジャーナルに残してからループを抜ける。

**終了条件チェック**:

- `blocked` または unresolved 扱いになった場合 → ループ終了 → Phase 4 へ
- `iteration >= 6` → ループ終了 → Phase 4 へ
- それ以外 → `iteration++` して Step 1 へ

---

## Phase 4: Refactor Review（デフォルト有効・スキップ可）

レビュー・修正ループが収束（findings 0件 / トリアージで全件除外 / 6イテレーション到達 / blocked）した直後に1回だけ実行する。
**ユーザーが事前に「リファクタはスキップ」「skip refactor」等を明示している（`skip_refactor = true`）場合は実行せず Phase 5 へ進む。**

リファクタ観点はバグ・要件逸脱とは独立した品質軸であり、Step 1 のレビューに混ぜず専用プロンプトで分離する。

### Step 1: Refactor Review（Codex）

Agentツールで `general-purpose` サブエージェントを起動し、その中で `codex exec` をリファクタ専用プロンプトで実行させる。差分は `/tmp/review_diff.patch` を再利用してよい（直前の修正で更新する）。

Codex プロンプトの要旨:

```text
あなたはリファクタリングレビュー担当です。バグや要件逸脱は別フェーズで対応済みなので、ここでは品質観点のみを指摘してください。

差分ファイル: /tmp/review_diff.patch
合意済み要件: {requirements_summary}
合意済み設計: {design_summary}

以下の観点でレビューしてください:
- 重複コード（3箇所以上の繰り返しは抽出を検討）
- 命名の改善（曖昧、誤解を招く、不揃い）
- 過剰設計の除去（YAGNI 違反、未使用抽象、未使用フラグ、不要な早すぎる抽象化）
- 既存パターンとの整合（周辺ファイルのスタイル、命名、ファイル配置に合わせる）
- 不要なコメント・デッドコード・コメントアウト
- データ構造・関数分割の改善余地

各指摘は以下のフォーマット:

### [REFACTOR] 指摘タイトル
- **ファイル**: `ファイルパス:行番号`
- **問題**: 何が冗長/不明瞭か
- **理由**: なぜ改善すべきか（可読性 / 保守性 / 既存パターンとの整合）
- **修正例**: before/after の diff（必須）

機能の振る舞いを変える提案は禁止。テストが必要な変更は指摘しない。
```

実行後、結果を `/tmp/codex_refactor.txt` から読み取り、`refactor_findings += findings数` で集計する。

```
Refactor Review (Codex): {N}件の指摘
```

findings が0件なら Phase 5 へ進む。

### Step 2: スコープ判定 + ユーザー選定

- ベースブランチ差分外への指摘は除外する（既存コードの大掃除はスコープ外）
- 残った指摘を番号付きでユーザーに提示する
- ユーザーが採用する番号を選ぶ（`all` / `none` / `1,3,5` 形式）
- `none` の場合は Phase 5 へ進む

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

## Phase 5: Security Review（デフォルト有効・スキップ可）

Phase 4 が完了した（またはスキップされた）あとに1回だけ実行する。`skip_security = true` の場合は実行せず最終サマリーへ進む。

セキュリティ観点はバグレビューと一部重なるが、専用プロンプトで明示的に網羅する価値があるため独立フェーズとして扱う。

### Step 1: Security Review（Codex）

Agentツールで `general-purpose` サブエージェントを起動し、Codex にセキュリティ専用プロンプトでレビューさせる。差分は更新された `/tmp/review_diff.patch` を使う。

Codex プロンプトの要旨:

```text
あなたはセキュリティレビュー担当です。本差分に新規・潜在的なセキュリティリスクがないかを集中的にチェックしてください。

差分ファイル: /tmp/review_diff.patch
合意済み要件: {requirements_summary}
合意済み設計: {design_summary}

以下の観点で網羅的にレビュー:

- 認証・認可の欠落や bypass（権限チェックの抜け、IDOR、未認証エンドポイント）
- 入力検証（SQL injection、command injection、XSS、path traversal、SSRF、XXE、deserialization）
- 出力エンコーディング（HTML/JS/JSON コンテキストでのエスケープ）
- 秘密情報の取り扱い（ログ、エラーメッセージ、git に commit される .env、URL クエリへの token 露出）
- 暗号化（弱いアルゴリズム、固定IV/nonce、自前実装、平文保存）
- セッション/トークン管理（有効期限、回転、HttpOnly/Secure cookie、CSRF対策）
- 依存ライブラリ（既知の脆弱性のあるバージョン、信頼できないソース）
- レースコンディション・TOCTOU
- ファイルアップロード/ダウンロードの検証
- レート制限・abuse 対策の欠如
- ロギング・監査の不足（重要操作のログ欠落、機密値のログ出力）

各指摘は以下のフォーマット:

### [SEC-{HIGH|MEDIUM|LOW}] 指摘タイトル
- **ファイル**: `ファイルパス:行番号`
- **脅威**: 何が悪用されうるか（攻撃シナリオを具体的に）
- **影響**: 悪用された場合のインパクト
- **修正方針**: 推奨される緩和策
- **修正例**: before/after の diff（HIGH/MEDIUM は必須、LOW は任意）

severity 基準:
- HIGH: リモート悪用可、機密データ漏洩、権限昇格に直結
- MEDIUM: 特定条件下で悪用可、または現行コードの安全性が局所的に成立しているだけ
- LOW: defense in depth の観点で改善が望ましいレベル

不確実な場合も指摘してください。確証がなければ「要確認」と明記して構いません。
```

実行後、結果を `/tmp/codex_security.txt` から読み取り、`security_findings += findings数` を集計する。

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
Iterations: {N}
Total findings: {累計指摘件数}
Fixed: {累計修正件数}
Directives: {固定されたdirective件数}

Refactor: {refactor_findings 件指摘 / refactor_fixed 件修正}{skip 時: "skipped"}
Security: HIGH {N} / MEDIUM {N} / LOW {N} / fixed {N}{skip 時: "skipped"}

{残存指摘がある場合:
Remaining issues:
- [SEVERITY] {指摘タイトル} ({ファイル}) — {理由: 修正不能/6イテレーション到達/HIGH残存等}
}
```

セキュリティ HIGH が残存している場合は、最終サマリー先頭で **強調表示** すること（ユーザーが見落とさないように）。
