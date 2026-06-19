# 出力バンドルの構造

最終成果物は **自己完結したバンドル(ディレクトリ)** で、ネットワーク無しでブラウザから
開ける。単一ファイルではない。ビューを別ファイルに切り分けることで、ビューを **追加型**
にできる(1 ビューずつ増やせる)。

```
<bundle>/
  index.html          シェル(ヘッダ + 左ペインのプロンプト + 右ペインのビュー切替 + 1 つの iframe)
  views.json          順序付きマニフェスト: {"views":[{"id","label","file"}, ...]}
  core.yaml           コピーされて入る。プロンプトが絶対パスで参照する
  view.yaml           コピーされて入る
  views/
    01-<id>.html       iframe ビュー文書(完全な <!DOCTYPE html>、ライトデフォルト)
    02-<id>.html
```

`scripts/build_html.py` がこの形を作って維持する。これは **アセンブラ**: シェルを書き、
ビューをマニフェストにマージする。`core.yaml` から決め打ちの図を引くことはしない。

## シェル (`index.html`)

ヘッダ + 2 ペイン:

```text
header                    タイトル + サブタイトル + ライト/ダークの THEME TOGGLE
main layout (2 panes)
  左ペイン:    プロンプトテンプレ(「ビュー追加」カード、コピーボタンつき)
              core.yaml / view.yaml ビューア(タブ切替、表示のみ)
              ヘルプ / 使い方
  右ペイン:    ビュー切替(マニフェスト 1 件につき 1 タブ)
              1 つの <iframe src="views/<file>#theme=...">(現在のビュー)
inline <style> / <script>   (外部 CSS / JS なし)
```

- ワイド画面では 2 ペイン横並び。狭い画面では 1 カラムにスタック。
- **デフォルトでライト**。ヘッダのトグルでシェルに `data-theme="dark"` を立てる。
  ストレージは禁止なので、reload するとライトに戻る。
- `prefers-reduced-motion` を尊重、キーボード操作可能、可視 focus。

## 右ペインのビュー切替 + iframe

- 1 つの `<iframe id="view-frame" sandbox="allow-scripts" src="views/<file>#theme=...">`。
- `views.json` の各エントリに対して 1 タブ。タブクリックで `iframe.src` をそのビューに
  切り替える。
- シェルは自身のテーマを **URL ハッシュ**(`#theme=dark|light`)で cross-origin iframe に
  伝える。各ビューは自分の `location.hash` を読み(load と `hashchange` の両方)。
- `sandbox="allow-scripts"`(決して `allow-same-origin` を付けない): iframe はユニーク
  origin で走り、parent DOM / storage / cookies に届かない。

## 各ビュー文書 (`views/NN-<id>.html`)

- 対象と読み手向けに作り込んだ **完全な HTML 文書**。ローカル `src` で読まれる。
- 表現は **固定ではない** — table / worktree / cards / faq / comparison / sequence /
  reading path / risk map / dependency map / glossary / tutorial / review checklist …
- 必ず含める: 出典、重要概念、関係、次に読むべき箇所、次の質問。視覚構造を持つこと
  (フラットなプローズにしない)。
- **ライトデフォルト**、`#theme` ハッシュ経由でダーク対応。詳細は
  `html-generation-rules.md`。

## プロンプトテンプレ(左ペイン)

- チャット UI ではない。ローカルファイルを読める AI に「もう 1 つビューを作ってくれ」と
  頼むためのカード群。
- 各カード: タイトル、用途説明、プロンプト本文(`<details>` で折り畳み)、コピーボタン、
  任意のタグ。
- プロンプトは YAML を **絶対パス**(`{{core_yaml_path}}` / `{{view_yaml_path}}`)で参照し、
  YAML の内容は埋め込まない。
- 必要セットは `prompt-template-patterns.md`、スターターは `sample-prompts.json`。

## YAML ビューア(左ペイン)

- `core.yaml` / `view.yaml` が読み取り専用テキストとして埋め込まれ、タブで切り替え可能
  (表示専用)。
- これがバンドルの自己説明性を担保する。プロンプト側はこの埋め込みコピーではなく、
  **ディスク上のファイル** を絶対パスで指す。

## マニフェスト (`views.json`)

- ビュー一覧と順序の唯一の真実。タブもファイル名もここから derive する。再ビルドすると
  既存ビューを保ったまま新しいビューが **append** される。

## 出力の安全性

- ネットワーク通信なし、外部 script / CSS なし、リモート iframe なし、storage なし、
  cookie なし。
- iframe は parent に届かない(`allow-same-origin` を付けない)。ローカル相対 `src` は OK、
  リモート `src` は禁止。
- `index.html` と全 `views/*.html` を `scripts/validate_html.py` で検証する。
