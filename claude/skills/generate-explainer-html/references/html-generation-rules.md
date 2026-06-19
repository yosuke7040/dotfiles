# HTML 生成ルール

この skill で AI が HTML を生成するときに守るルール。通常の運用で書くのは **内側の
iframe ビュー文書だけ**。外側のシェル(`index.html`)は決定論的な `scripts/build_html.py`
が書く。手書きしない。目標は **オフラインで自己完結、安全** なバンドルが、固定テンプレ
ではなく **読み手に合わせて** 説明 UI を変えること。

この skill の中心はレンダラーではない。中心は (1) `core.yaml` の意味、(2) `view.yaml` の
戦略、(3) 柔軟な iframe ビュー文書群、(4) コピー可能なプロンプトテンプレ。本ルールは
(3) を安全かつ役立つ状態に保つためのもの。

出力は **バンドル(ディレクトリ)**: `index.html` + `views.json` + `core.yaml` /
`view.yaml` + `views/NN-<id>.html`(ビュー 1 つにつき 1 ファイル)。シェルの右ペインは
`iframe src="views/<file>"` でビューを 1 つずつ読み込み、タブで切り替える。ビューは
**追加型** で、新しく作るたびに別タブになる。

## 安全ルール(硬い要件)

生成 HTML(外側 / iframe 内側を問わず) の中で以下を **禁止** する:

- 外部 `<script src=...>`
- 外部 CSS(`<link rel="stylesheet">` やリモート `@import`)
- 外部 / リモートの `<iframe src=...>`
- `<object>`, `<embed>`
- `fetch(...)`
- `XMLHttpRequest`
- `WebSocket`
- `localStorage`
- `sessionStorage`
- `document.cookie`
- `window.parent` へのアクセス
- `window.top` へのアクセス
- top ナビゲーション(`target="_top"`, `window.top.location` など)
- 外部エンドポイントへの form submit
- API キーやシークレットの埋め込み
- ソーステキストの大きな verbatim 貼り付け

`scripts/validate_html.py` がこれらをチェックし、見つかったら fail させる。ユーザーに
渡す前に必ず通す。`http://` / `https://` 文字列も fail させる(本当にオフラインなバンドル
は URL を必要としない)。

## 許可されているもの

- inline `<style>`(CSS)
- inline `<script>`(JS)
- iframe **内側で完結する** UI インタラクション
- `<details>` / `<summary>`
- タブ、アコーディオン、フィルタ
- コピーボタン(clipboard API、フォールバック textarea つき)
- 開閉ツリー
- クライアント側だけのインタラクション(ネットワーク無し、ストレージ無し、frame 脱出無し)

## iframe 契約

- iframe は **必須**。シェルから説明 UI を隔離する。
- シェルは各ビューを `views/` の **ローカル相対 `src`** で読み込む。これはローカル
  ファイル読み込みであってネットワーク読み込みではない。リモート `src`(スキーム `://`
  または `//`)は依然禁止。
- **必ず** `sandbox="allow-scripts"` を付ける。
- **`allow-same-origin` は絶対に付けない**(付けると parent に届いてしまう)。

```html
<iframe sandbox="allow-scripts" src="views/01-engineer.html#theme=light"></iframe>
```

`allow-same-origin` が無いので、iframe はユニーク origin で走り、parent DOM、parent
storage、parent cookies のどれにも触れない。これがほしい挙動。

> **ブラウザ注:** Chrome / Edge は `file://` での iframe サブリソース読み込みを
> ブロックする。`file://` で開くなら Firefox。あるいはバンドル内で簡易ローカル
> サーバを立てる(それでもローカルファイルしか読まないので、ネットワーク禁止のルールは
> 守られる — このルールは **コンテンツ** を縛る)。

## 各ビュー文書のテーマ契約

- 各ビュー文書は **デフォルトでライト**。
- シェルは cross-origin の sandbox iframe を直接スタイルできないので、現在のテーマを
  iframe URL の hash 経由で渡す: `views/<file>#theme=dark` または `#theme=light`。
- 各ビュー文書は load 時に自分の `window.location.hash` を読み、**さらに**
  `hashchange` を listen して、`document.documentElement` の `data-theme="dark"` を
  set/unset する。
- ライトの `:root` パレットと `:root[data-theme="dark"]` のダークパレットを両方
  CSS 変数で定義する。正確なパターンは `sample-iframe.html` を見る。

## UI ルール

- 表現は読み手の `view.yaml` から選ぶ。固定テンプレを強制しない。統一感より理解しやすさ
  を優先する。
- 情報量が多いなら、**progressive disclosure**(details / タブ / "もっと見る")で見せる。
  ベタ書きの壁にしない。
- **importance / difficulty / confidence** を視覚的に読めるようにする(バッジ、色、順序)。
  低い confidence は「自信無さげ」に見せる。
- **出典(source references)** は必ず見せて、主張を辿れるようにする。
- **次に読むべきもの(reading order / path)** を必ず見せる。
- **次に AI に聞くとよい質問** を必ず見せる。
- **アクセシビリティ**: セマンティック見出し、ラベル付きコントロール、可視 focus、十分な
  コントラスト、キーボード操作可能。
- **レスポンシブ**: 狭い画面でも使える(シェルは 1 カラムにスタックする)。
- **`prefers-reduced-motion`** を尊重: 本質的でないアニメ / トランジションは切る。

## 内側 UI のコンテンツルール

iframe 文書は段落のベタ書きにしない。次を含めること:

- 重要 **概念** とその importance / difficulty / confidence
- 概念どうしの **関係**
- **次に読むべき場所**
- **出典**
- **次に AI に聞くとよい質問**
- 読み手の `view.yaml` に合った理解スタイル
- **視覚構造**(グルーピング、階層、バッジ)を持つこと。プローズだけにしない。

## 実用チェックリスト

1. 与えられた絶対パスで `core.yaml` と `view.yaml` を Read する。
2. `view.yaml.presentation.preferred_forms` から形式を選び、`avoid_forms` を避ける。
3. iframe **ビュー** 文書を 1 つ起こす(完全な `<!DOCTYPE html>`、inline CSS / JS のみ、
   ライトデフォルト + `#theme` ハッシュ対応)。
4. 必須コンテンツブロック(concepts, relations, reading order, sources, next questions)を
   入れる。
5. シェル用のプロンプトテンプレを書く / 維持する(`prompt-template-patterns.md` 参照)。
6. `scripts/build_html.py --bundle <dir> --view-html "ラベル=その.html"` でバンドルを
   ビルド / 拡張する(タブとして追加される)。
7. `scripts/validate_html.py <dir>/index.html <dir>/views/*.html` でバリデート。指摘を
   直して再バリデート。
8. ネットワーク無しで開けるブラウザでバンドルをユーザーに渡す(Firefox の `file://`、
   または Chrome ならフォルダを serve)。
