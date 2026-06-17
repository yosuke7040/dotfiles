---
name: using-agent-skills
description: エージェントスキルを発見して呼び出す。セッション開始時、または現在のタスクにどのスキルが適用されるかを見つける必要がある場合に使う。これは全スキルの発見と呼び出し方を管理するメタスキルである。
---

# エージェントスキルの使用

## 概要

Agent Skills は、開発フェーズごとに整理されたエンジニアリング workflow skill の集合である。各 skill は、シニアエンジニアが従う特定のプロセスを符号化している。このメタスキルは、現在のタスクに適した skill を見つけて適用するためのもの。

## スキル発見

タスクが来たら、開発フェーズを特定し、対応する skill を適用する。

```
タスク到着
    │
    ├── まだ欲しいものが分からない？ ─────────→ interview-me
    ├── 粗い構想があり、案を広げたい？ ──────→ idea-refine
    ├── 新規 project / feature / change？ ───→ spec-driven-development
    ├── spec があり、task 化したい？ ───────→ planning-and-task-breakdown
    ├── code 実装中？ ─────────────────────→ incremental-implementation
    │   ├── UI 作業？ ─────────────────────→ frontend-ui-engineering
    │   ├── API 作業？ ────────────────────→ api-and-interface-design
    │   ├── context が足りない？ ──────────→ context-engineering
    │   ├── docs で検証した code が必要？ ─→ source-driven-development
    │   └── stakes が高い / 不慣れな code？ → doubt-driven-development
    ├── test を書く / 実行する？ ───────────→ test-driven-development
    │   └── browser-based？ ───────────────→ browser-testing-with-devtools
    ├── 何か壊れた？ ─────────────────────→ debugging-and-error-recovery
    ├── code review？ ────────────────────→ code-review-and-quality
    │   ├── 複雑すぎる？ ─────────────────→ code-simplification
    │   ├── security concerns？ ──────────→ security-and-hardening
    │   └── performance concerns？ ───────→ performance-optimization
    ├── commit / branch 作業？ ────────────→ git-workflow-and-versioning
    ├── CI/CD pipeline 作業？ ─────────────→ ci-cd-and-automation
    ├── deprecate / migrate？ ────────────→ deprecation-and-migration
    ├── docs / ADR を書く？ ───────────────→ documentation-and-adrs
    ├── logs / metrics / alerts を追加？ ─→ observability-and-instrumentation
    └── deploy / launch？ ────────────────→ shipping-and-launch
```

## 中核の動作原則

これらはすべての skill をまたいで常に適用する。交渉不可。

### 1. 前提を表面化する

重要な実装を始める前に、前提を明示する。

```
置いている前提:
1. [requirements に関する前提]
2. [architecture に関する前提]
3. [scope に関する前提]
→ 違う場合は今修正してください。この前提で進めます。
```

曖昧な要件を黙って補わない。最も多い失敗は、間違った前提を作り、それを確認せずに走ること。不確実性は早く出す。手戻りより安い。

### 2. 混乱を能動的に扱う

不整合、競合する要件、不明確な仕様に出会ったら:

1. **止まる。** 推測で進まない。
2. 何が具体的に混乱しているか名指しする。
3. trade-off を提示するか、確認質問をする。
4. 解決するまで待つ。

**悪い:** 片方の解釈を黙って選び、正しいことを祈る。  
**良い:** 「spec では X ですが既存 code は Y です。どちらを優先しますか？」

### 3. 必要なら押し返す

明確な問題がある approach には yes-machine にならない。

- 問題を直接指摘する
- 具体的な downside を説明する（可能なら「約 200ms latency が増える」のように定量化する）
- 代替案を出す
- 十分な情報を得たうえで人間が上書きするなら受け入れる

迎合は失敗モードである。「もちろんです！」と言って悪い案を実装しても誰の助けにもならない。正直な技術的不同意は、見せかけの同意より価値がある。

### 4. 単純さを強制する

自然な傾向は複雑にしすぎること。能動的に抵抗する。

実装を終える前に問い直す。

- もっと少ない行でできないか？
- この抽象化は複雑さに見合っているか？
- staff engineer が見て「なぜ単にこうしなかったのか」と言わないか？

1000 行書いて 100 行で足りるなら失敗である。退屈で明白な解を優先する。巧妙さは高い。

### 5. scope discipline を保つ

依頼されたものだけ触る。

してはいけないこと:

- 理解していないコメントを削除する
- タスクに直交する code を「clean up」する
- 副作用として隣接 system を refactor する
- 明示的な承認なしに、未使用に見える code を削除する
- 「便利そう」という理由で spec にない機能を追加する

仕事は外科的な精度であって、頼まれていない改装ではない。

### 6. 仮定せず検証する

すべての skill には検証 step がある。検証が通るまでタスクは完了ではない。「正しそう」は十分ではない。passing tests、build output、runtime data などの証拠が必要である。

## 避けるべき失敗モード

生産性に見えるが問題を作る微妙な失敗:

1. 間違った前提を確認せずに置く
2. 自分の混乱を管理せず、迷ったまま突き進む
3. 気づいた不整合を表面化しない
4. 非自明な判断で trade-off を提示しない
5. 明確な問題がある approach に迎合する（「もちろんです！」）
6. code や API を複雑にしすぎる
7. タスクに直交する code や comments を変更する
8. 完全には理解していないものを削除する
9. 「明らかだから」と spec なしで作る
10. 「見た目は正しい」と検証を飛ばす

## スキルルール

1. **作業開始前に適用できる skill を確認する。** Skill はよくあるミスを防ぐプロセスを符号化している。

2. **Skill は提案ではなく workflow である。** 手順通りに従う。検証 step を飛ばさない。

3. **複数の skill が適用されることがある。** Feature 実装では `idea-refine` → `spec-driven-development` → `planning-and-task-breakdown` → `incremental-implementation` → `test-driven-development` → `code-review-and-quality` → `code-simplification` → `shipping-and-launch` のように順に使うことがある。

4. **迷ったら spec から始める。** タスクが重要で spec がないなら、`spec-driven-development` から始める。

## ライフサイクル順序

完全な feature では、典型的な skill sequence は次の通り。

```
1.  interview-me                → ユーザーが実際に欲しいものを引き出す
2.  idea-refine                 → 曖昧なアイデアを磨く
3.  spec-driven-development     → 何を作るか定義する
4.  planning-and-task-breakdown → 検証可能な小片へ分解する
5.  context-engineering         → 適切な context を読み込む
6.  source-driven-development   → 公式 docs で確認する
7.  incremental-implementation  → slice ごとに構築する
8.  observability-and-instrumentation → 作りながら計装する（7-9 と並行。後ではない）
9.  doubt-driven-development    → non-trivial な判断を進行中に反対尋問する
10. test-driven-development     → 各 slice が動くことを証明する
11. code-review-and-quality     → merge 前に review する
12. code-simplification         → 振る舞いを保ちつつ不要な複雑さを減らす
13. git-workflow-and-versioning → clean commit history にする
14. documentation-and-adrs      → 判断を文書化する
15. deprecation-and-migration   → 必要に応じて古い system を廃止し、安全に移行する
16. shipping-and-launch         → 安全に deploy する
```

すべてのタスクにすべての skill が必要なわけではない。bug fix なら `debugging-and-error-recovery` → `test-driven-development` → `code-review-and-quality` だけで足りることがある。

## クイックリファレンス

| フェーズ | Skill | 一行要約 |
|-------|-------|----------|
| Define | interview-me | 計画・仕様・code の前に、ユーザーが実際に欲しいものを表面化する |
| Define | idea-refine | 発散と収束を構造化してアイデアを磨く |
| Define | spec-driven-development | code の前に requirements と acceptance criteria を定義する |
| Plan | planning-and-task-breakdown | 小さく検証可能な task へ分解する |
| Build | incremental-implementation | 薄い vertical slice を作り、広げる前に各 slice を test する |
| Build | source-driven-development | 実装前に公式 docs で検証する |
| Build | doubt-driven-development | non-trivial な判断を fresh-context で adversarial review する |
| Build | context-engineering | 適切な context を適切なタイミングで読む |
| Build | frontend-ui-engineering | accessibility を含む production-quality UI を作る |
| Build | api-and-interface-design | 明確な contract を持つ安定 interface を作る |
| Verify | test-driven-development | 失敗する test を先に書き、通す |
| Verify | browser-testing-with-devtools | Chrome DevTools MCP で runtime verification を行う |
| Verify | debugging-and-error-recovery | reproduce → localize → fix → guard |
| Review | code-review-and-quality | 5 軸 review と quality gate |
| Review | code-simplification | 振る舞いを保ちながら不要な複雑さを減らす |
| Review | security-and-hardening | OWASP prevention、input validation、least privilege |
| Review | performance-optimization | 先に測定し、重要なものだけ最適化する |
| Ship | git-workflow-and-versioning | atomic commits、clean history |
| Ship | ci-cd-and-automation | すべての change に automated quality gate |
| Ship | deprecation-and-migration | 古い system を削除し、users を安全に移行する |
| Ship | documentation-and-adrs | what だけでなく why を文書化する |
| Ship | observability-and-instrumentation | structured logs、RED metrics、traces、symptom-based alerts |
| Ship | shipping-and-launch | pre-launch checklist、monitoring、rollback plan |
