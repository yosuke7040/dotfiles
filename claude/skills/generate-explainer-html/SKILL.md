---
name: generate-explainer-html
description: core.yaml(意味)と view.yaml(見せ方戦略)から、ドキュメント・リポジトリ・PR・設計メモ・スペックなどの理解を助ける、自己完結した HTML バンドルを生成する skill。バンドルはライト/ダーク切り替えのシェルを持ち、右ペインで複数の iframe ビュー(エンジニア向け / 初心者向け / テーブル / ワークツリー …)を切り替えられ、コピー可能なプロンプトテンプレ経由で別ビューを追加できる。ユーザーが core.yaml / view.yaml ペアを持っている / 作りたいときに使う。事前に generate-explainer-yaml で YAML を作っておくこと。
---

# generate-explainer-html

`core.yaml`(意味)と `view.yaml`(見せ方戦略)のペアを **自己完結した HTML バンドル**
に変換する skill。バンドルは以下を提供する:

- 右ペインの **iframe 内に読み手向けの説明 UI** を出し、**ビュー切り替えタブ** で
  複数の表現を切り替えられる。
- iframe の外側に **コピー可能なプロンプトテンプレ** を並べ、ローカルファイルを読める
  別の AI に「もう 1 つ別ビューを足してくれ」と頼める。

これはパイプラインの **後半**。`core.yaml` / `view.yaml` は
**`generate-explainer-yaml`** skill が作る(またはユーザーが用意する)。この skill は
それを **絶対パスで** 読み、iframe ビュー文書を起こし、バンドルを組み立てる。

```
core.yaml + view.yaml  (generate-explainer-yaml から受け取る)
  ↓ 設計 + 生成(この skill)
HTML バンドル: index.html (ライト/ダークのシェル + ビュー切り替え + プロンプトカード)
            + views/NN-<id>.html  (切り替え可能な iframe ビューを 1 つずつ)
```

## バンドル(出力)

出力は **単一ファイルではなく、ディレクトリ**:

```
<bundle>/
  index.html          シェル: ヘッダ(テーマ切替) + 左ペインのプロンプト + 右ペインのビュー切替 + 1 つの <iframe>
  views.json          ビュー一覧の順序付きマニフェスト {id, label, file}
  core.yaml           コピーされて入る(プロンプトが絶対パスで参照する)
  view.yaml           コピーされて入る
  views/
    01-<id>.html       iframe ビュー文書(完全な <!DOCTYPE html>、デフォルトはライト)
    02-<id>.html
```

右ペインの iframe は `src="views/<file>"` で 1 つずつビューを読み込み、タブで切り替える。
ビューは **追加型**: 新しく作るたびに別タブになり、既存ビューやシェル / プロンプトは
書き換わらない。

`index.html` とプロンプトは **手で編集しない** — 唯一の書き手は `scripts/build_html.py`。
ユーザー(と AI)が書くのは **iframe ビュー文書だけ**。Web アプリ、サーバ、API、チャット UI
は作らない。外部 CDN / CSS / JS にも依存しない。

## 手順

1. **YAML ペアを受け取る**。`generate-explainer-yaml` skill またはユーザーから、
   `core.yaml` / `view.yaml` の **絶対パス** を取る。**それを Read する**。
   まだ無いなら、先に `generate-explainer-yaml` で作る。

2. **iframe ビュー文書を 1 つ書く** — 対象と読み手向けに調整した完全な `<!DOCTYPE html>`。
   形式は `view.yaml` から選ぶ(table / worktree / cards / faq / comparison / sequence /
   reading path / risk・dependency・impact map / glossary / tutorial / review checklist …)。
   出典、重要概念、関係、次に読むべき箇所、次の質問を必ず含め、実際の視覚構造を持たせる。
   **デフォルトはライト**、自分の URL ハッシュ(`#theme`)を読んでダークにも対応する
   (`load` と `hashchange` の両方)。inline CSS / JS のみ、ネットワーク禁止。
   詳細は `references/html-generation-rules.md`、例は `references/sample-iframe.html`。

3. **プロンプトテンプレを書く** — `prompts.json` の配列として、「ビューを追加する」カード
   (table / worktree / beginner / engineer / PdM・Biz / 自由記述)を用意する。
   各テンプレは `{{core_yaml_path}}` / `{{view_yaml_path}}` で YAML の絶対パスを参照し、
   **YAML の中身は埋め込まない**。パターン: `references/prompt-template-patterns.md`、
   スターター: `references/sample-prompts.json`。

4. **バンドルをビルドする**(下記参照)。`scripts/build_html.py` に `--core` / `--view`
   (コピーされて、プロンプトの絶対パスプレースホルダに使われる)と、1 つ以上の
   `--view-html "ラベル=その.html"` を渡す。

5. **バリデート**。`scripts/validate_html.py` を `index.html` と **すべての**
   `views/*.html` に対して実行する。エラーが消えるまで直して再実行。exit 0 にする。

6. **バンドルフォルダをユーザーに渡す**。下記の「開き方」案内を添える。
   どのビューが入っているか、どの「ビュー追加」テンプレが使えるかを要約する。

## 後からビューを足す(追加型のフロー)

既存ビューに別表現を **追加する** とき(上書きしない):

1. もう 1 つ iframe ビュー文書を書く(またはコピーしたプロンプトを別 AI に渡す。
   プロンプトには「YAML を絶対パスで読み、新しいビューを 1 つだけ返せ」と書いてある)。
2. **新しいビューだけ** を渡して再ビルド:

   ```bash
   python scripts/build_html.py --bundle <dir> --prompts <prompts.json> \
     --view-html "テーブル=table.html"
   ```

   `views.json` にビューが **append** され、`index.html` が新しいタブ付きで再生成される。
   既存ビュー・シェル・プロンプトは保持される。同じラベルで再実行すると、そのビューだけ
   in-place で更新される(重複しない)。

## スクリプトの使い方

> `python` が PATH に無ければ `python3` で叩く。

ビルド / 拡張:

```bash
python scripts/build_html.py \
  --bundle ./explainer-bundle \
  --core /abs/path/core.yaml \
  --view /abs/path/view.yaml \
  --prompts prompts.json \
  --view-html "エンジニア=engineer.html" \
  --view-html "テーブル=table.html"
```

`--bundle` と `--prompts` は必須。`--core` / `--view` は推奨(プロンプトが絶対パスで
参照する)。省略した再ビルドでは既存のものを残す。`--view-html` は繰り返し可で、
追加/更新を行う。

バリデート(安全性 / 自己完結性チェック):

```bash
python scripts/validate_html.py ./explainer-bundle/index.html ./explainer-bundle/views/*.html
```

`build_html.py` は **アセンブラ** であってレンダラーではない。`core.yaml` から固定の図を
吐くことはしない。理解 UI は手順 2 で書く iframe ビュー文書側にある。

## バンドルの開き方

- **Chrome / Edge は `file://` での iframe 読み込みをブロック** する。`file://` で開くなら
  **Firefox** を使う。あるいはバンドルディレクトリ内で簡易ローカルサーバを立てる
  (例: `python3 -m http.server` を **バンドルディレクトリ内** で実行 — これはローカル
  ファイルしか読まないので、ネットワーク禁止のルールに反しない。「コンテンツがオフラインで
  あること」を縛るルールであって、配信方法を縛るルールではない)。
- 右ペインのタブでビューを切り替える。ヘッダのトグルでライト/ダークが切り替わり、
  `#theme` ハッシュ経由で iframe にも伝わる。

## トラブルシュート

- **`validate_html.py` が `http://` / `https://` で fail する** — `source_ref` か
  プロンプト本文に URL が漏れている。ここでは URL は live link ではなくラベル: スキームを
  落とす(`example.com/path`)か、URL を消してから再バリデート。
- **`validate_html.py` が `fetch(` / `XMLHttpRequest` / `localStorage` などで fail する** —
  プロンプト本文か view ファイルに禁止トークンが literal に出ている。汎用的に言い換える。
  `references/prompt-template-patterns.md` の「プロンプト本文での安全な言い回し」節を参照。
- **Chrome の `file://` で iframe が真っ白** — 想定通り。Firefox を使うか、フォルダを
  サーブする。
- **`build_html.py: --view-html must be "LABEL=PATH"`** — 各ビューは `ラベル=パス` 形式で渡す。
- **`build_html.py: no views to build`** — `--view-html` を最低 1 つ渡すか、すでに
  `views.json` が入ったバンドルに対して再ビルドする。
- **ビュータブが 404** — `views/NN-*.html` が消されている。`--view-html` で再生成する。
- **入力が空・自明** — 説明すべき実体が無いなら、ユーザーに実際のドキュメント / リポジトリ /
  PR を聞き、まず YAML を作る。空の解説を出さない。

## 同梱サンプルで試す

```bash
python scripts/build_html.py \
  --bundle ./sample-bundle \
  --core ../generate-explainer-yaml/references/sample-core.yaml \
  --view ../generate-explainer-yaml/references/sample-view.yaml \
  --prompts references/sample-prompts.json \
  --view-html "エンジニア=references/sample-iframe.html"

python scripts/validate_html.py ./sample-bundle/index.html ./sample-bundle/views/*.html
```

`sample-bundle/index.html` を開く(Firefox か serve)。右ペインにエンジニア向けの PR 解説
(worktree + 読む順番 + レビューチェックリスト)、左ペインにコピー用「ビュー追加」テンプレと
YAML ビューア。

## 参照ファイル

- `references/html-generation-rules.md` — ビュー文書の安全 / UI ルール
  (src で読み込む iframe、ライトデフォルト、`#theme` ハッシュ)
- `references/output-bundle-structure.md` — バンドルの構造とシェル
- `references/prompt-template-patterns.md` — 「ビュー追加」プロンプトテンプレ + パスのプレースホルダ
- `references/sample-iframe.html` — サンプル iframe ビュー(エンジニア向け)
- `references/sample-prompts.json` — サンプル「ビュー追加」テンプレ
- 兄弟 skill の YAML スキーマ: `../generate-explainer-yaml/references/`
  (`core-yaml-schema.md`, `view-yaml-schema.md`)
