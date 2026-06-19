# core.yaml — 理解対象の意味構造

`core.yaml` は「対象が **何を意味しているか**」を捕まえるためのファイル。
「どう見せるか」は書かない。これは後段の各ステップ(view 戦略、HTML 生成、プロンプト
テンプレ)が乗っかる唯一の意味的真実。意図的に UI 非依存にしてあるので、同じ
`core.yaml` をテーブル、ワークツリー、FAQ、シーケンス、何にでもレンダリングできる。

## メンタルモデル

```
入力(doc / repo / PR / 設計メモ / spec)
   ↓ 分析
core.yaml  ← 概念、関係、重要度、難易度、根拠、出典への参照
```

`core.yaml` は **意味の地図** と考える:

- *concepts* — 理解する価値のあるもの(ファイル、モジュール、考え方、判断、リスク …)
- *relations* — それらがどう繋がるか(depends_on, calls, changes, contrasts, …)
- *importance / difficulty / confidence* — どこに注意と注意深さを向けるべきか
- *source_refs* — 根拠。どの主張も出典に遡れるようにする

## やる / やらない

- ✅ 意味、構造、重要度、難易度、根拠を書く。
- ✅ 小さく保つ。重要なところに圧縮する。ソース全文を写さない。
- ❌ レイアウト、色、コンポーネント、「これをテーブルで描け」は書かない。
- ❌ 原文の長い verbatim を貼らない(短い抜粋のみ)。
- ❌ 事実を捏造しない。不確かなら `confidence` を下げて `question` を足す。

## スキーマ (`version: core/v1`)

```yaml
version: core/v1

target:
  type: document | repository | pull_request | design_note | spec | other
  title: string            # 人間向けの短いタイトル
  summary: string          # 1〜3 文: この対象は何か
  source_label: string     # どこから来たか(例: "PR #482", "README")

concepts:
  - id: string             # relations / questions / risks から参照される安定 id
    label: string          # 短い表示名
    kind: file | module | function | concept | flow | decision | risk | actor | requirement | unknown
    summary: string        # 1 行
    detail: string         # もう少し深い説明(任意)
    importance: low | medium | high
    difficulty: low | medium | high
    confidence: number      # 0.0〜1.0、どれだけ自信があるか
    source_refs:            # この concept 自体の根拠(任意)
      - id: string
        path: string        # ファイルパス、または論理的な所在
        url: string         # 任意。基本は省略推奨(後述「URL の扱い」)
        excerpt: string     # 短い引用。全文ではない
        lines:
          start: number
          end: number

relations:
  - id: string
    from: string            # concept id
    to: string              # concept id
    type: depends_on | calls | contains | changes | affects | explains | contrasts | sequence_next | blocks | supports | unknown
    label: string           # エッジの短いラベル
    reason: string          # なぜこの関係があるか
    confidence: number

questions:                  # 読み手がまだ聞くべきこと
  - id: string
    question: string
    why_it_matters: string
    related_concept_ids:
      - string

risks:                      # 何が起こりうるか / 注意が必要なこと
  - id: string
    label: string
    description: string
    severity: low | medium | high
    related_concept_ids:
      - string

source_refs:                # トップレベルの出典レジストリ(任意、重複排除済み)
  - id: string
    title: string
    type: file | diff | document | url | note
    path: string
    url: string             # 任意 — 後述参照
    excerpt: string
```

## フィールド注

- **id** が糊。安定で一意に保つ。relations / questions / risks は concept id を指す。
- **importance と difficulty は別軸**。「理解しておく価値」と「理解の難しさ」は違う。
  両方が生成 UI の視覚的強調に効く。
- **confidence** は誠実さの指標。低い confidence は UI で見えるマーカーになるべきだし、
  しばしば `question` として表に出すべき。
- **source_refs** が信頼性を担保する。重要 concept は `path`(できれば `lines` まで)で
  辿れるようにする。

## URL の扱い(オフライン安全性)

最終 HTML は **オフラインで自己完結** することが要件で、`validate_html.py` は
`http://` / `https://` という文字列を外部依存の可能性として fail させる。なので:

- 出典の識別は `path`、`title`、`excerpt` を優先する。
- どうしても URL を残したい場合は **ラベル**として扱う。生成 HTML には載せないか、
  `http`/`https` スキームを落として `example.com/path` のように書く。こうすれば
  出力はオフラインかつ validator を通る。

## 最小例

```yaml
version: core/v1
target:
  type: pull_request
  title: "公開 API にレート制限を追加"
  summary: "公開 API ミドルウェアとしてトークンバケットのレート制限を導入する。"
  source_label: "PR #482"
concepts:
  - id: c_middleware
    label: "RateLimitMiddleware"
    kind: module
    summary: "上限を超えたリクエストを拒否する。"
    importance: high
    difficulty: medium
    confidence: 0.9
    source_refs:
      - id: r_mw
        path: "src/api/middleware/rate_limit.py"
        lines: { start: 14, end: 76 }
relations:
  - id: rel1
    from: c_middleware
    to: c_store
    type: depends_on
    label: "トークンを問い合わせる"
    confidence: 0.95
```

より充実したサンプルは `sample-core.yaml` を見る。
