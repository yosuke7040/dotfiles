---
name: multi-agent-review-and-fix
description: ハーネスエンジニアリングに基づくマルチエージェント実装支援スキル。Codex主導で要件把握と設計検討を行い、必要に応じて初回実装を起こした後、Codexレビュー→Claudeトリアージ→修正→検証のループでコード品質を段階的に改善する。PR URL はベースブランチ推定にも使えるが、実際のレビュー対象は現在のローカル HEAD とする。
argument-hint: [ベースブランチ or PR URL（省略時はmain。PR URLはベースブランチ推定専用）]
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(date:*), Bash(mkdir:*), Bash(ls:*), Bash(rm:*), Bash(codex:*), Agent
---

# マルチエージェント実装レビュー＆修正

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

- **Phase 1とPhase 2では実装しない**。この段階の仕事は要件明確化と設計検討だけ
- **要件が曖昧、または設計案が複数あって決め切れない場合は必ずユーザー確認を取る**。未確定のまま実装に進まない
- **オーケストレーターはレビューもコード変更もしない**。Codexにレビューさせ、実装・修正は修正エージェントに委譲する
- **`/dev-journal` を併用し、要件・設計判断・主要アクションを都度記録する**
- **各イテレーションの終了時に `dev-journal` を更新する**。指摘件数、採否判断、修正内容、directive、テスト結果、残課題を必ず残す
- **最大6イテレーション**。通常2-3回で収束する。6回到達時は残存指摘を報告して終了する
- **オシレーション検出時はdirectiveで固定**。A→B→Aの振り子パターンを検出したら、優れた方を選びdirectiveとして以降のイテレーションに強制適用する

---

## Phase 0: 準備とベースブランチ決定

`$ARGUMENTS` を解析する:

1. **引数なし**: ベースブランチは `main`
2. **ブランチ名**: 指定されたブランチをベースとする
3. **PR URL**（`https://github.com/owner/repo/pull/123` 形式）: `gh pr view` でベースブランチを取得する

PR URL を指定しても、このスキルがレビュー・修正対象とするのは **現在のローカル `HEAD`** である。
対象PRの差分を扱いたい場合は、先にそのPR相当のブランチをローカルで checkout しておくこと。

現在のブランチがベースブランチと同じ場合はエラー終了する。

```
━━━ multi-agent-review-and-fix 開始 ━━━
対象: {現在のブランチ} → {ベースブランチ}
```

次の準備を行う:

- `/dev-journal` が未実行なら先に実行し、ジャーナルを開始する
- プロジェクトのコーディングガイドラインを確認する（`CLAUDE.md`、`.eslintrc`、`pyproject.toml` の `[tool.ruff]` セクション等）
- タスクの要件ソースを特定する
  - GitHub Issue URL や `owner/repo#123` があれば `gh issue view` で取得する
  - PR URL があれば PR の title / body を取得する
  - それ以外はユーザーとの会話内容を要件ソースとして扱う
- 現時点の差分を `git diff {ベースブランチ}...HEAD` で確認し、存在する場合は後続フェーズの参考情報として保持する

### イテレーション管理用の内部状態

以下をフェーズ間・イテレーション間で保持する:

- `requirements_summary`: 合意済みの要件サマリー
- `design_summary`: 合意済みの設計サマリー
- `iteration`: 現在のイテレーション番号（1始まり）
- `validate_retries`: 同一イテレーション内でのValidate差し戻し回数
- `history`: 各イテレーションの修正内容の要約（オシレーション検出用）
- `directives`: 固定されたdirective一覧
- `total_findings`: 累計指摘件数
- `total_fixed`: 累計修正件数

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

cat << 'PROMPT' | codex exec --ephemeral -m gpt-5.4 -c model_reasoning_effort="xhigh" -s read-only -o /tmp/codex_requirements.txt -
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
PROMPT

cat /tmp/codex_requirements.txt
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

cat << 'PROMPT' | codex exec --ephemeral -m gpt-5.4 -c model_reasoning_effort="xhigh" -s read-only -o /tmp/codex_design.txt -
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
PROMPT

cat /tmp/codex_design.txt
```

オーケストレーターは結果を受け取り、以下を行う:

- `Open Questions` にブロッカーがある場合は、ユーザーに確認して停止する
- ブロッカーがない場合は `design_summary` として保持し、`/dev-journal` に記録する
- 要件サマリーと設計案をユーザーに提示し、承認を得るまで次に進まない

> **ユーザーレビュー**: 要件サマリーと設計案の承認を得てから次に進む

---

## Phase 3: 初回実装の有無確認

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

まず差分を一時ファイルに保存してください:
git diff {ベースブランチ}...HEAD > /tmp/review_diff.patch

次に以下のコマンドでCodexを実行してください（timeout: 600000）:

cat << 'PROMPT' | codex exec --ephemeral -m gpt-5.4 -c model_reasoning_effort="xhigh" -s read-only -o /tmp/codex_review.txt -
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
- **修正案**: どう修正すべきか

SEVERITYは以下のいずれか:
- CRITICAL: バグ、データ不整合、意図と異なる動作、要件逸脱
- IMPORTANT: 潜在的問題、特定条件で壊れやすい設計、設計逸脱
- LOW: スタイル、パフォーマンス微改善、冗長コード

偽陽性よりも偽陰性を避けることを優先してください。怪しいものは指摘し、判断はトリアージに委ねてください。
差分だけでは判断できない場合は、ワーキングディレクトリの周辺コードも参照してください。
PROMPT

cat /tmp/codex_review.txt

Codexが結果を返さなかった場合（ファイルが空や存在しない場合）は、同じコマンドを1回だけ再実行してください。
再実行でも結果が得られない場合は「Codexが最終結果を返せなかった」と報告してください。自分で代替レビューを行わないこと。
```

レビュー結果を受け取り、件数を記録する。

- `total_findings += findings数`

```
Review (Codex): {N}件の指摘
```

**findingsが0件の場合**: Step 6 でジャーナル更新を行ってからループを終了し、最終サマリーへ。

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

**トリアージ後のfindingsが0件の場合**: Step 6 でジャーナル更新を行ってからループを終了し、最終サマリーへ。

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

- `blocked` または unresolved 扱いになった場合 → ループ終了
- `iteration >= 6` → ループ終了
- それ以外 → `iteration++` して Step 1 へ

---

## ループ終了後: 最終サマリー

```text
━━━ Review Complete ━━━
Requirements: {要件サマリーの要点}
Design: {採用設計の要点}
Iterations: {N}
Total findings: {累計指摘件数}
Fixed: {累計修正件数}
Directives: {固定されたdirective件数}

{残存指摘がある場合:
Remaining issues:
- [SEVERITY] {指摘タイトル} ({ファイル}) — {理由: 修正不能/6イテレーション到達}
}
```
