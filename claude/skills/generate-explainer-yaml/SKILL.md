---
name: generate-explainer-yaml
description: ドキュメント・リポジトリ概要・PR / diff・README・設計メモ・スペックなどの「理解対象」を分析し、その意味構造を表す core.yaml と、ある読み手に向けた見せ方戦略を表す view.yaml の 2 ファイルを生成または更新する skill。HTML バンドル生成の前段として動く。既存の core.yaml / view.yaml を編集してリシェイプする用途にも使う。生成された YAML は generate-explainer-html skill が読み取って、切り替え可能なライト/ダークの HTML バンドルに組み立てる。
---

# generate-explainer-yaml

理解対象 — 貼り付けられたドキュメント、リポジトリ概要、PR / diff 要約、README、設計メモ、
スペックなど — を、HTML 解説バンドル生成パイプラインが食う
**2 つの中間 YAML ファイル**に変換する skill。

1. `core.yaml` — 対象の **意味構造**(UI ではない): 概念、関係、重要度、難易度、確信度、
   質問、リスク、根拠への参照。
2. `view.yaml` — **この読み手にどう見せるか**: 想定読者の役割と習熟度、好む表現形式、
   避ける形式、密度、トーン、強調したい軸、生成方針。

この skill はパイプラインの **前半** で、HTML は出さない。YAML ペアができたら
**`generate-explainer-html`** skill がそれを絶対パスで読み込んで、切り替え可能な
ライト/ダーク HTML ビューバンドルを組み立てる。

```
入力(ドキュメント / リポジトリ概要 / PR diff / README / 設計メモ / 任意の技術テキスト)
  ↓ 分析(この skill)
core.yaml   (概念、関係、重要度、難易度、根拠、出典)
view.yaml   (想定読者、好む/避ける形式、密度、強調)
  ↓ 設計 + 生成(generate-explainer-html skill)
HTML バンドル(index.html + 切り替え可能な iframe ビュー群)
```

## この skill がやること

- 新規入力から `core.yaml` と `view.yaml` を **生成**する。
- 既存の `core.yaml` / `view.yaml` を **編集してリシェイプ**する(概念を足す、関係を直す、
  `view.yaml` の対象読者を切り替える、強調を調整する、構造を整える)。

## どこに書くか

YAML は **パスが固定される安定したディレクトリ**に書く。最も自然なのは、HTML skill が
あとでバンドルを置く場所(例: `./explainer-bundle/core.yaml` と
`./explainer-bundle/view.yaml`)か、ユーザーが残しておくプロジェクトフォルダ。HTML skill は
これらをバンドル内にコピーし、**絶対パス**を再生成プロンプトに埋め込むので、ローカル
ファイルを読める別 AI が後でその YAML を読み直せる。一時的な `/tmp` のような捨てパスは使わない。

## 手順

1. **入力を読む**。ユーザーが貼ったもの、または指したパスを取る。対象タイプを判定する
   (document / repository / pull_request / design_note / spec …)。

2. **`core.yaml` を書く**。*意味* を捕まえる: concepts(`importance` / `difficulty` /
   `confidence` 付き)、relations、questions、risks、`source_refs`。コンパクトに。
   ソースを丸ごと書き写さず、重要なところに圧縮する。不確かなときは `confidence` を下げ、
   `question` を足す。事実を捏造しない。スキーマ: `references/core-yaml-schema.md`、
   サンプル: `references/sample-core.yaml`。

3. **`view.yaml` を書く**。*この読み手* にどう見せるかを決める: 役割と習熟度、好む形式と
   避ける形式、密度、トーン、強調したい軸、`html_generation_policy`。ユーザーが何も指定
   していなかったら妥当な戦略を推定し、**仮定を明記する**。スキーマ:
   `references/view-yaml-schema.md`、サンプル: `references/sample-view.yaml`。

4. **両ファイルを安定したディレクトリに書き出し**、ユーザーに **絶対パス**を返す。これを
   `generate-explainer-html` に渡せばバンドルが作れる。

5. **(編集モード)** 既存 YAML を直すときは、まず現在のファイルを Read する。要求を満たす
   **最小の変更**だけ入れる。`id` の値は変えない(relations / questions / risks が指している)。
   `version:` は維持する。

## generate-explainer-html への引き渡し

YAML を書いたら、次は `generate-explainer-html`:

```
generate-explainer-html を使って
  --core /abs/path/core.yaml --view /abs/path/view.yaml
からビュー付きの HTML バンドルを作ってください。
```

## 注意

- **`core.yaml` は読み手非依存、`view.yaml` は読み手依存**。意味と表現を分けておくことで、
  同じ `core.yaml` を `view.yaml` だけ差し替えて別の読み手向けに作り直せる。
- **オフライン安全性が下流まで効く**。最終 HTML はオフライン・自己完結で、validator は
  `http://` / `https://` のような文字列を全部 fail させる。`source_ref` の `url` は **生のリンク
  ではなくラベル**として扱い、`path` / `title` / `excerpt` を優先する。URL を残したい場合は
  スキームを落とす(`example.com/path` のように書く)。詳細は
  `references/core-yaml-schema.md` の「URL の扱い」節を見る。

## 参照ファイル

- `references/core-yaml-schema.md` — 意味構造スキーマ (`core/v1`)
- `references/view-yaml-schema.md` — 表現戦略スキーマ (`view/v1`)
- `references/sample-core.yaml` — サンプル `core.yaml`(PR を題材)
- `references/sample-view.yaml` — サンプル `view.yaml`(その PR をレビューするエンジニア向け)
