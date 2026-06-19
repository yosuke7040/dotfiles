# /explainer - YAML/HTML 解説バンドル生成

理解対象(PR / ドキュメント / 設計メモ / README / リポジトリ概要 / 任意の技術テキスト)
から、`generate-explainer-yaml` と `generate-explainer-html` skill を順に走らせて、
オフライン自己完結の HTML 解説バンドルを 1 つの command で作る。**特に GitHub PR の
レビュー補助**を主眼に置く。

## 使い方

```
/explainer <PR URL>
/explainer <owner/repo#N>
/explainer <ファイルパス>
/explainer <自由テキストや diff を貼り付け>
```

オプション(任意):

- `--reader engineer | beginner | pdm | biz | custom` — 想定読者(既定 `engineer`)。
- `--bundle <dir>` — 出力ディレクトリ(既定 `./explainer-bundle`)。
- `--views <名前,…>` — 作るビュー。reader と合わせて自動選択するが、明示も可
  (`エンジニア`, `テーブル`, `ワークツリー`, `初心者`, `PdM`, `自由`)。
- `--no-html` — YAML 生成だけで止める(レビュー用)。
- `--include-comments` — PR URL の場合に PR コメント / レビュースレッドも取得して
  入力に含める(既定は body + diff のみ)。
- `--base <ref>` — diff の比較先 base を上書き(PR URL 以外。PR URL では PR の
  `baseRefName` が使われる)。

例:

```
/explainer https://github.com/handy-inc/handy-front/pull/1395
/explainer --reader pdm --views "PdM,テーブル" https://github.com/handy-inc/handy/pull/234
/explainer --no-html ./docs/design/auth.md
/explainer --include-comments handy-inc/handy-front#1395
```

## 実行手順(Claude が踏むステップ)

### Step 0: 引数解析

1. オプションを取り出す(`--reader` `--bundle` `--views` `--no-html`
   `--include-comments` `--base`)。残りを **対象引数** とする。
2. 対象引数の種別を判定(上から優先):

   | 形 | 例 | 解釈 |
   | --- | --- | --- |
   | `https://github.com/<owner>/<repo>/pull/<N>` | URL | **PR URL モード** |
   | `<owner>/<repo>#<N>` | 短縮 | PR URL モード(短縮形) |
   | 既存ファイルパス | `./docs/x.md` | **ファイルモード** |
   | 既存ディレクトリパス | `./src/api` | **ディレクトリモード** |
   | それ以外の文字列 | 貼り付け diff/メモ | **インラインモード** |

3. `--bundle` 未指定なら既定値。同 path に **既存バンドル** があれば、ビュー追加モード
   として動く(既存 `core.yaml` / `view.yaml` を尊重する。Step 2 を skip して Step 3 から)。

### Step 1: PR URL モードの入力収集(該当時のみ)

1. **gh 認証確認**:

   ```bash
   gh auth status 2>&1 | head -5
   ```

   未認証ならエラー終了し、ユーザーに `gh auth login` を案内する(自動で実行しない)。

2. **PR メタ情報を取得**:

   ```bash
   gh pr view <N> --repo <owner>/<repo> \
     --json number,title,body,headRefName,baseRefName,headRepositoryOwner,additions,deletions,changedFiles,url,isCrossRepository
   ```

3. **PR diff を取得**:

   ```bash
   gh pr diff <N> --repo <owner>/<repo>
   ```

   ファイルが多い PR では、まず `--patch` 抜きで `gh pr view` の `changedFiles` を確認し、
   下記のサイズ制御に従う。

4. **(任意)コメント / レビューを取得**(`--include-comments` 時のみ):

   ```bash
   gh pr view <N> --repo <owner>/<repo> --comments
   gh api repos/<owner>/<repo>/pulls/<N>/reviews --jq '.[] | {user: .user.login, state, body}'
   ```

5. **サイズ制御**(意味抽出には全行不要なので過剰量に注意):

   - diff が **5,000 行超** → `AskUserQuestion` で「続行 / 主要ファイルだけ抽出 / 中止」を確認。
   - `changedFiles` が **30 件超** → ファイル一覧 + stat + 上位 10 ファイルの抜粋に圧縮。
   - body が空・極端に短い場合は WARNING(意味抽出が薄くなるが続行)。

6. **入力テキストの組み立て**(`generate-explainer-yaml` への渡しもの):

   ```
   target_type: pull_request
   source_label: PR #<N> (<owner>/<repo>)
   title: <title>
   url: <url>           # スキーマ落として "github.com/..." 表記
   base: <baseRefName> → head: <headRefName>
   additions/deletions/changedFiles: +A/-B, files F
   body: <PR body 全文>
   diff_stat: <gh pr diff --stat 相当>
   changed_files: <一覧>
   diff_excerpt: <主要ファイルの diff、サイズ制御済み>
   (--include-comments 時) comments: <整形した会話履歴>
   ```

   一時ファイルに書く: `/tmp/explainer_input_<sid>.md`(`sid` は `uuidgen | head -c 8`)。

### Step 2: YAML 生成 (`generate-explainer-yaml`)

1. `--bundle <dir>` を mkdir し、その絶対パスを `BUNDLE_ABS` に保持。
2. `generate-explainer-yaml` skill を起動して、以下の指示を渡す:

   ```
   入力テキスト(またはファイル) <path or content> を読んで、
   <BUNDLE_ABS>/core.yaml と <BUNDLE_ABS>/view.yaml を生成してください。

   想定読者: <reader>
     - engineer  → role: engineer / familiarity: intermediate /
                   preferred_forms: [worktree, reading_path, review_checklist]
     - beginner  → role: beginner  / familiarity: beginner /
                   preferred_forms: [beginner_tutorial, glossary, faq]
     - pdm / biz → role: business / familiarity: intermediate /
                   preferred_forms: [impact_map, faq, decision_map]
     - custom    → AskUserQuestion で詳細を確認

   PR URL モードの場合は target.type=pull_request、source_label を上記の通りに。
   source_refs には changed files の path を入れる(URL スキームは落とす)。
   ```

3. skill が書いた **絶対パス** を確認する(`<BUNDLE_ABS>/core.yaml` /
   `<BUNDLE_ABS>/view.yaml`)。

4. `--no-html` 指定時はここで終了。バンドル下の YAML 絶対パスを提示して終わる。

### Step 3: ビュー作成 (`generate-explainer-html` 前段)

`--views` が指定されていればその名前を使い、未指定なら reader から自動選択:

| reader | 既定ビュー |
| --- | --- |
| engineer | `エンジニア` を 1 つ(worktree + reading_path + review_checklist) |
| beginner | `初心者` を 1 つ(beginner_tutorial + glossary + faq) |
| pdm | `PdM` を 1 つ(impact_map + decision_map + faq) |
| biz | `PdM` を 1 つ(impact_map + faq、より要約寄せ) |
| custom | AskUserQuestion で確認 |

各ビューにつき 1 つ、**iframe ビュー文書(完全な `<!DOCTYPE html>`)** を起こす。ルールは
`generate-explainer-html` skill の `references/html-generation-rules.md` に従う:

- inline CSS / JS のみ。ネットワーク・ストレージ・親フレームアクセス禁止。
- ライトデフォルト + `#theme` ハッシュでダーク対応。
- 必須要素: 重要概念 / 関係 / 次に読むべき箇所 / 出典 / 次に AI に聞くとよい質問。

書き出し先: `/tmp/explainer_view_<sid>_<ラベル>.html`。

### Step 4: バンドル組み立て (`build_html.py`)

```bash
SKILL_DIR=$(realpath ~/.claude)/skills/generate-explainer-html
# あるいはこの dotfiles 配下から見る: claude/skills/generate-explainer-html
python3 "${SKILL_DIR}/scripts/build_html.py" \
  --bundle "${BUNDLE_ABS}" \
  --core   "${BUNDLE_ABS}/core.yaml" \
  --view   "${BUNDLE_ABS}/view.yaml" \
  --prompts "${SKILL_DIR}/references/sample-prompts.json" \
  --view-html "<ラベル1>=/tmp/explainer_view_<sid>_<ラベル1>.html" \
  --view-html "<ラベル2>=/tmp/explainer_view_<sid>_<ラベル2>.html"
```

`--view-html` は作ったビュー分だけ繰り返す。同じバンドルへの再実行 = **追加**。

### Step 5: バリデート

```bash
python3 "${SKILL_DIR}/scripts/validate_html.py" \
  "${BUNDLE_ABS}/index.html" "${BUNDLE_ABS}/views/"*.html
```

exit 0 になるまで直して再実行。落ちた場合の典型対応:

- `http://` / `https://` を踏んだ → `source_refs` か prompt 本文の URL を直す(スキームを
  落とすか除去)。
- `fetch(` `XMLHttpRequest` `localStorage` `document.cookie` `window.parent`
  `window.top` などのトークンを踏んだ → ビュー文書 or prompt 本文で literal に出ている。
  汎用的に言い換える。

### Step 6: ユーザーへ報告

以下を 1 つの最終応答にまとめる:

```markdown
# /explainer 結果

## 📦 バンドル
- 出力先: <BUNDLE_ABS>
- 含まれるビュー: <ラベル1>, <ラベル2>, …
- core.yaml: <BUNDLE_ABS>/core.yaml
- view.yaml: <BUNDLE_ABS>/view.yaml

## 📝 入力サマリー
- 対象: <PR タイトル / ファイル名 / インライン入力>
- (PR の場合) <PR URL> / base ← head / +A/-B / files F

## 🌐 開き方
- Firefox で <BUNDLE_ABS>/index.html を開く、または
- `cd <BUNDLE_ABS> && python3 -m http.server` で serve して Chrome で開く

## 🎯 次アクション候補
- 別読者向けビューを追加: `/explainer --reader pdm --bundle <BUNDLE_ABS>` を再実行
- 意味側(core.yaml)を直す: `generate-explainer-yaml で core.yaml を編集して` と指示
- ビューを 1 種類削りたい: <BUNDLE_ABS>/views.json と views/*.html を手動で除去後、
  `build_html.py --bundle <BUNDLE_ABS> --view-html "<別ラベル>=..."` で再構築
```

### Step 7: 一時ファイル後始末

```bash
[ -e "/tmp/explainer_input_<sid>.md" ] && rm "/tmp/explainer_input_<sid>.md"
for f in /tmp/explainer_view_<sid>_*.html; do
  [ -e "$f" ] && rm "$f"
done
```

`-f` / `2>/dev/null || true` は使わない(失敗を黙殺せず、明示的に存在チェック)。

## 設計メモ / 注意点

- **PR URL モードのスコープ**: この command は GitHub 上の **PR スナップショット**
  (body + diff + 任意で会話履歴)を読んで解説する。ローカルの worktree や checkout は
  触らない。コードベースの周辺ファイルに踏み込んだ深いレビューが必要なら、別ツールの方が
  向く。
- **submodule 集約 PR(handy-root 配下など)**: URL の owner/repo が指す GitHub 上の
  PR をそのまま見る。親リポジトリや他 submodule との整合性チェックはやらない。
- **巨大 PR**: サイズ制御で抜粋に絞っても意味は抽出できる。すべての diff を残したいなら
  `--include-comments` のような追加ロードは控える。
- **コメント/レビューを含める時の注意**: 議論文脈は強い情報源になるが、意味抽出が
  「コメントの揉め事」に引っ張られないよう、`generate-explainer-yaml` には「PR body と
  diff を主、コメントは補助」と明示する。
- **再現性**: `core.yaml` を保存しているので、後から `view.yaml` だけ書き換えれば
  別読者向けに作り直せる(意味は同じ)。これがこの skill 群の旨味なので、command で
  破棄せず必ずバンドル直下に置く。
- **モデルの選び方**: `generate-explainer-yaml` は意味抽出なので推論精度が効く。HTML
  ビュー生成は表現の問題でテンプレ寄り。両方とも skill の指示書に従う限り、特に
  モデル指定は不要。
