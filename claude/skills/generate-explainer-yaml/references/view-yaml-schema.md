# view.yaml — ある 1 人の読み手向けの表現戦略

`view.yaml` は `core.yaml` とは違う質問に答える:

- `core.yaml` = **対象が何を意味するか**(読み手非依存)
- `view.yaml` = **この読み手が一番早く理解するためにどう見せるか**(読み手依存)

これは決め打ちレンダラーへの命令ではない。HTML 生成 AI に「どの表現形式を優先するか」
「どれを避けるか」「どれくらい密に書くか」「何を強調するか」を伝える **中間表現**。
同じ `core.yaml` でも `view.yaml` が違えば、明確に違う HTML ができるべき。

## なぜファイルを分けるか

理解は個人的。ある人はテーブルで考え、別の人はワークツリー、カード、FAQ、対比、シーケンス、
ストーリー、読む順番、影響マップで考える。「意味」と「表現」を分けておくと、
**同じ意味**を `view.yaml` を差し替えるだけで別読者に向け直せる。これは iframe 限定の
「再生成」プロンプトテンプレートがやっていることそのもの。

## スキーマ (`version: view/v1`)

```yaml
version: view/v1

audience:
  role: engineer | designer | product_manager | business | beginner | custom
  familiarity: beginner | intermediate | advanced | unknown
  stated_preferences:        # ユーザーが好きと言った形式
    - worktree
    - sequence
  dislikes:                  # この読み手向けには避ける形式
    - dense_table

intent:
  primary_goal: string       # この読み手が一番欲しいもの
  secondary_goals:
    - string

presentation:
  preferred_forms:           # iframe UI をこれらに寄せる
    - worktree
    - cards
    - faq
  avoid_forms:
    - dense_table
  density: low | medium | high
  tone: concise | friendly | technical | tutorial
  visual_style: string       # 自由テキスト、例: "clean, readable, not decorative"
  interaction_level: low | medium | high   # 開閉・フィルタ・タブをどれくらい入れるか

focus:
  emphasize:                 # どの軸を前に出すか
    - purpose
    - impact
    - dependencies
    - risks
    - reading_order
  de_emphasize:
    - minor_details

html_generation_policy:
  allow_creative_layout: true
  must_include:              # UI に必ず含める
    - overview
    - source_references
    - prompt_templates
  should_include:            # あると望ましい
    - progressive_disclosure
    - visual_grouping
    - next_questions
  must_not_include:          # 安全 / スコープ上の硬い制限
    - external_script
    - remote_css
    - network_request
```

## `preferred_forms` / `avoid_forms` の語彙

これは生成器への **示唆**であって、閉じた enum ではない。よく使う値:

`table`, `worktree`, `cards`, `faq`, `comparison`, `sequence`, `timeline`,
`reading_path`, `risk_map`, `dependency_map`, `glossary`, `beginner_tutorial`,
`review_checklist`, `decision_map`, `impact_map`, `story`.

複数を組み合わせて良い(例: *worktree + reading_path + review_checklist*)。

## フィールド注

- **stated_preferences / dislikes** が一番強いシグナル。これは尊重する。
  読み手が `dense_table` を嫌がっているなら、テーブル一辺倒の UI を主役にしない。
- **density** は progressive disclosure をどれだけ使うか。`high` は全部見せ、`low` は
  小さい overview を開閉で広げる。
- **interaction_level** はクライアント側のインタラクション(タブ、フィルタ、開閉ツリー)
  の量を決める。すべて iframe 内、ネットワークは禁止。
- **focus.emphasize** は `core.yaml` 側の軸(importance, difficulty, risk, relations,
  reading order)のうちどれを視覚的に大きく見せるかをマップする。
- **html_generation_policy.must_not_include** は安全契約。外部スクリプト、リモート CSS、
  ネットワーク通信は常に禁止 — `html-generation-rules.md` 参照。

## ユーザーが指定しなかったときの推定

ユーザーが好みを言わなかったら、文脈から妥当な `view.yaml` を推定し、**仮定を明記** する。
たとえば:

- 「この PR をレビューしたい」 → role `engineer`、forms `worktree + reading_path + review_checklist`。
- 「この仕様を経営層に説明したい」 → role `business`、forms `impact_map + faq`。
- 「自分はこの領域に詳しくない」 → role `beginner`、forms `beginner_tutorial + glossary + faq`。

推定が外れたときに読み手が方向修正できるよう、view 再生成プロンプトテンプレートも
一緒に置いておく。

PR レビューのエンジニア向けサンプルは `sample-view.yaml` を見る。
