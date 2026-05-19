---
name: review-branch
description: 任意のブランチ(ローカル/リモート両対応)とデフォルトブランチの差分を、Claude と Codex の 2エージェントで並列に辛口レビューし、結果を統合・整理して報告する skill。レビュー専用に git worktree を切ってから走らせるため、現在の作業ツリーを汚さない。修正は行わず、指摘の整理と報告までを担当する。
argument-hint: "[branch (省略時は現在のブランチ)] [--base <base> (省略時は origin/HEAD → main を自動判定)]"
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(date:*), Bash(mkdir:*), Bash(ls:*), Bash(rm:*), Bash(uuidgen:*), Bash(tr:*), Bash(head:*), Bash(basename:*), Bash(wc:*), Bash(awk:*), Bash(sed:*), Bash(grep:*), Bash(echo:*), Bash(test:*), Bash(codex:*), Agent
---

# review-branch

Claude と Codex の 2エージェントによる **辛口** ブランチレビュー skill。
git worktree を切ってからレビューするので、現在の作業ツリーを汚さない。

## 目的とスコープ

### やること
- 指定ブランチ(ローカル/リモート)のための git worktree 作成
- そのブランチと base(既定: main / origin/HEAD)との差分取得
- Claude(`general-purpose` subagent)と Codex(`codex exec`)を並列に起動
- 両者の指摘を統合・整理してユーザーへ報告

### やらないこと(非スコープ)
- コード修正、コミット、push、PR 作成
- 要件・設計の議論(`/codex-second-opinion` を使う)
- 修正→再レビューのループ(`/spec-driven-feature-dev` を使う)

修正したい指摘がレポートに含まれる場合、ユーザーに次アクション候補を示すだけにする。

## 全体方針

- **サブエージェントは細かく辛口、最終報告はトリアージ後**。
  - 各レビュアー(Codex / Claude subagent)へのプロンプトには「忖度・お世辞・楽観視は禁止」「LOW でも気になれば挙げる」を強く入れ、**生の指摘はできるだけ多く出させる**
  - 一方で **ユーザーへの最終報告は skill オーケストレーター(=このskillを実行する Claude 本体)が必ず Step 4 でトリアージしてから出す**。生の指摘をそのまま流さない
- 実ファイルへの書き込み・コミット・push は行わない。ただし指摘内に diff/コード例（before→after の小片）を含めるのは推奨
- CRITICAL / IMPORTANT は具体的な修正例（diff か小片コード）を必ず添える。書き直し規模が大きく示しきれない場合のみ方針のみ可とし、その旨を明記する
- LOW は方針のみで可（必要に応じて命名例などを併記）
- 抽象論で逃げない。「考慮すべき」「検討してほしい」で止めず、どうコードが変わるかまで踏み込む
- 指摘は差分行(追加/変更行)に限定する。差分外コードへの放言は禁止
- 両者の指摘は重複統合し、片方のみの指摘は帰属を明記して残す(信頼度の手がかり)
- **最終レポートはレビュアー別に分割しない**。指摘リストは Step 4.1 で統合、総評は Step 4.5 で融合し、ユーザーに渡すのは「まとめあげた1本」だけにする。帰属ラベルは指摘リスト内に残し、信頼度の手がかりとする
- **視認性**: 最終レポートでは、各指摘の見出しに triage ランク（必読/要確認/軽微）を `[ランク N]` 形式で明示し、指摘どうしは `---` で区切る。H2 セクションが画面外に出ても各指摘のランクが一目で分かるようにする（特に「必読 CRITICAL」と「要確認に降格された CRITICAL」を取り違えないため）

---

## Step 0: 引数解釈と入力決定

### 引数パース
- 第1引数: `branch`(省略時は現在のブランチ `git branch --show-current`)
- `--base <base>`: 比較先ブランチ(省略時は自動判定)

### base の自動判定(優先順位)
1. `git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null` の末尾(例: `origin/main` → `main`)
2. `main`(`git rev-parse --verify main` で実在確認)
3. `master`(`git rev-parse --verify master` で実在確認)

どれもなければエラー終了し、ユーザーに `--base` 明示を促す。

### branch の存在判定
```bash
# ローカル
if git rev-parse --verify --quiet "refs/heads/${BRANCH}"; then
  BRANCH_KIND=local
else
  # リモートを最新化
  git fetch --prune origin
  if git rev-parse --verify --quiet "refs/remotes/origin/${BRANCH}"; then
    BRANCH_KIND=remote
  else
    # 両方ない → エラー終了
    exit 1
  fi
fi
```

### 早期エラー
- `BRANCH == BASE` ならエラー終了(差分が出ない)
- branch が見つからない → エラー終了

---

## Step 1: worktree 作成

### パス決定
```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
SAFE_BRANCH=$(echo "${BRANCH}" | tr '/:' '__')
WT_PATH="${REPO_ROOT}/.worktrees/${SAFE_BRANCH}"
```

`.gitconfig` の `[wt] basedir = .worktrees` 規約に合わせ、リポジトリ直下の `.worktrees/` 配下に置く。

### 既存 worktree の扱い
```bash
# 同パスがすでに登録されているか確認
if git worktree list --porcelain | awk '/^worktree /{print $2}' | grep -Fxq "${WT_PATH}"; then
  if [ -d "${WT_PATH}" ]; then
    # 再利用: 最新化のみ
    REUSED=true
  else
    # 登録だけ残ってる → 掃除
    git worktree prune
    REUSED=false
  fi
fi
```

### 新規作成

**ローカルブランチの場合:**
```bash
git worktree add "${WT_PATH}" "${BRANCH}"
```

**リモートブランチの場合(ローカルに同名なし):**
```bash
git worktree add -b "${BRANCH}" "${WT_PATH}" "origin/${BRANCH}"
```

**ローカル/リモート両方に同名がある場合:** ローカルを優先(`git worktree add "${WT_PATH}" "${BRANCH}"`)し、最終報告に「ローカル `<branch>` とリモート `origin/<branch>` の差分の有無」を 1 行添える。

### `.gitignore` の確認(警告のみ)
`.worktrees/` がリポジトリの `.gitignore` に未登録の場合、最終報告の末尾で警告する(skill では `.gitignore` を編集しない)。

---

## Step 2: 差分取得

merge-base 起点で取得し、base 側の更新を含めない。

```bash
# 比較リファレンスは origin/<base> を優先(ローカル base が古いことがある)
if git -C "${WT_PATH}" rev-parse --verify --quiet "refs/remotes/origin/${BASE}" >/dev/null; then
  BASE_REF="origin/${BASE}"
else
  BASE_REF="${BASE}"
fi

MERGE_BASE=$(git -C "${WT_PATH}" merge-base "${BASE_REF}" HEAD)

git -C "${WT_PATH}" diff "${MERGE_BASE}..HEAD"            > /tmp/review_branch_diff_${SID}.patch
git -C "${WT_PATH}" diff --stat "${MERGE_BASE}..HEAD"     > /tmp/review_branch_stat_${SID}.txt
git -C "${WT_PATH}" diff --name-only "${MERGE_BASE}..HEAD" > /tmp/review_branch_files_${SID}.txt
```

### 早期終了・サイズチェック
- 差分 0 行 → 「差分なし」を報告し、Step 6 に飛んで worktree 後始末を案内
- diff の総行数が **5000 行超** → `AskUserQuestion` で「続行 / 中止 / 主要ファイルだけに絞る」を確認

---

## Step 3: 並列レビュー実行(本skillの中核)

### セッション ID
```bash
SID=$(uuidgen | tr '[:upper:]' '[:lower:]' | head -c 8)
```

### 実行順序

1. **先に Codex を `Bash run_in_background:true` で起動**(時間がかかる)
2. **直後に Agent ツールで Claude(`general-purpose`)を foreground 起動**
3. Agent が返ってきた後、`BashOutput` で Codex の終了を待つ
4. 両方の出力ファイルを Read して統合へ

### Codex 起動

`run_in_background: true` で起動し、Bash の shell ID を覚えておく。`BashOutput` で `[exit_code=0]` を確認してから出力ファイルを Read する。background 起動なら Bash ツール呼び出しは起動直後に return するため、Bash ツールの `timeout` パラメータは実プロセスには効かない（デフォルトのままで問題ない）。実プロセスの時間上限は shell 側 `timeout 1200`（= 最大20分）で明示している。

```bash
cat << PROMPT | timeout 1200 codex exec --ephemeral -m gpt-5.5 \
  -c model_reasoning_effort="xhigh" -s read-only -C "${WT_PATH}" \
  -o /tmp/review_branch_codex_${SID}.txt -
あなたは経験豊富なシニアエンジニアです。以下のブランチ差分を **辛口** でコードレビューしてください。

## 厳守事項
- 忖度・お世辞・楽観視は禁止。気になる点は遠慮なく挙げる
- 「動けばよい」基準ではなく「保守可能か」「将来バグらないか」「他人が読めるか」で評価
- "問題なし"・"良いと思います" のセクションは書かない。指摘だけ書く
- 実ファイルへの書き込み・コミット・push は禁止。ただし **指摘内の "修正例" に diff/小片コードを含めることは推奨**
- CRITICAL / IMPORTANT は具体的な修正例（diff 形式の最小コード片）を必ず添える。書き直し規模が大きく示しきれない場合のみ方針のみ可。その場合は `(方針のみ: 規模が大きいため diff 省略)` と明記する
- 抽象的なアドバイス("検討すべき"・"考慮するとよい")で終わらせない。どう直すかをコードで示すこと
- 指摘は差分行(追加/変更行)に限定する。差分外への放言は禁止
- 推測ではなく、根拠(具体的な失敗シナリオ・違反規約・読みにくさ等)を必ず示す

## 入力
- 差分: /tmp/review_branch_diff_${SID}.patch
- 統計: /tmp/review_branch_stat_${SID}.txt
- 変更ファイル一覧: /tmp/review_branch_files_${SID}.txt
- リポジトリ作業ツリー: ${WT_PATH}(必要に応じて Read してよい。ただし指摘は差分行のみ)

## ブランチ情報
- branch: ${BRANCH} (${BRANCH_KIND})
- base: ${BASE} (merge-base: ${MERGE_BASE})

## 出力フォーマット(Markdown)

### [SEVERITY] 指摘タイトル
- **ファイル**: \`path/to/file:line\`
- **問題**: 何が問題か(1-3行)
- **根拠**: なぜ問題と判断したか(具体的な失敗シナリオ・違反規約・読みにくさ等)
- **修正方針**: どう直すか(短文で方針を述べる)
- **修正例**: before/after を Markdown コードブロックで示す(diff 形式推奨)。**CRITICAL / IMPORTANT は必須**。書き直し規模が大きく diff として示しきれない場合のみ \`(方針のみ: 規模が大きいため diff 省略)\` と明記して省略可。LOW は任意

修正例のテンプレート(diff 形式):

\`\`\`diff
- logger.info(\`token=\${token}\`)
+ logger.info(\`token=\${maskToken(token)}\`)
\`\`\`

新規追加や複数箇所にまたがる場合は、関数単位の before/after でもよい。

SEVERITY の定義(必ず先頭にカラーマークを付ける):
- 🔴 CRITICAL: バグ・データ破損・セキュリティ・要件逸脱
- 🟡 IMPORTANT: 設計の歪み・将来の保守性低下・テスト欠如・性能問題
- 🔵 LOW: 命名・コメント・スタイル・微小な可読性

タイトル例: \`### 🔴 CRITICAL 認証トークンが平文ログに出力される\`

最後に "## サマリー" として 3〜5行の総評を辛口で書く。

No confirmations or questions are needed. Proactively provide concrete proposals, fixes, and code examples.
PROMPT
```

### Claude(general-purpose subagent)起動

`Agent` ツールで `subagent_type: "general-purpose"` を指定し、以下と同等の `prompt` を渡す:

```
あなたはコードレビュー専任のシニアレビュアー。**辛口** に評価してください。

## 厳守事項
- 忖度・お世辞・楽観視は禁止。気になる点は遠慮なく挙げる
- 「動けばよい」基準ではなく「保守可能か」「将来バグらないか」「他人が読めるか」で評価
- "問題なし"・"良いと思います" のセクションは書かない。指摘だけ書く
- 実ファイルへの書き込み・コミットは禁止。ただし **指摘の "修正例" 欄に diff/コード片を書くのは推奨**
- CRITICAL / IMPORTANT は具体的な修正例（diff 形式の最小コード片）を必ず添える。書き直し規模が大きい場合のみ `(方針のみ)` で省略可
- 抽象的なアドバイスで終わらせない。どう直すかをコードで示すこと
- 指摘は差分行(追加/変更行)に限定する。差分外への放言は禁止
- 推測ではなく、根拠(具体的な失敗シナリオ・違反規約・読みにくさ等)を必ず示す

## 入力
- 差分ファイル: /tmp/review_branch_diff_${SID}.patch
- 統計ファイル: /tmp/review_branch_stat_${SID}.txt
- 変更ファイル一覧: /tmp/review_branch_files_${SID}.txt
- リポジトリ作業ツリー: ${WT_PATH}(必要に応じて Read してよい。指摘は差分行のみ)

## ブランチ情報
- branch: ${BRANCH} (${BRANCH_KIND})
- base: ${BASE} (merge-base: ${MERGE_BASE})

## 出力フォーマット(Markdown)
最終メッセージにレビュー結果を Markdown で書いて返してください。

### [SEVERITY] 指摘タイトル
- **ファイル**: `path/to/file:line`
- **問題**: 何が問題か(1-3行)
- **根拠**: なぜ問題と判断したか
- **修正方針**: どう直すか(短文で方針を述べる)
- **修正例**: before/after を Markdown コードブロックで示す(diff 形式推奨)。**CRITICAL / IMPORTANT は必須**。書き直し規模が大きく示しきれない場合のみ `(方針のみ: 規模が大きいため diff 省略)` と明記して省略可。LOW は任意

修正例のテンプレート(diff 形式):

```diff
- logger.info(`token=${token}`)
+ logger.info(`token=${maskToken(token)}`)
```

SEVERITY(必ず先頭にカラーマークを付ける):
- 🔴 CRITICAL: バグ・データ破損・セキュリティ・要件逸脱
- 🟡 IMPORTANT: 設計の歪み・将来の保守性低下・テスト欠如・性能問題
- 🔵 LOW: 命名・コメント・スタイル・微小な可読性

タイトル例: `### 🔴 CRITICAL 認証トークンが平文ログに出力される`

最後に "## サマリー" として 3〜5行の総評を辛口で書いてください。
```

### 両者完了待ち
- Agent の戻り値に Claude のレビューが含まれている
- `BashOutput` で Codex の background shell の終了を確認し、`/tmp/review_branch_codex_${SID}.txt` を Read

### 失敗時のフォールバック
- 片方のみ失敗 → もう片方の結果だけで Step 4 に進み、レポートで失敗側を「未取得」と明示
- 両方失敗 → エラー報告して Step 6 へ

---

## Step 4: 結果統合とトリアージ

サブエージェントの生レビューはここで必ず処理する。**ユーザーに渡すのはトリアージ後のレポートだけ**。

### 4.1 重複統合(Merge)
- **同一ファイル + 同一行 ±3行 + 同一主旨** → 1件に集約し帰属を `共通(Claude+Codex)` とラベル
- 片方のみの指摘 → そのまま残し、末尾に `Claude のみ` または `Codex のみ` を付与
- severity が両者で食い違う → 高い方を採用(両者の表現はメモ欄に残す)

### 4.2 トリアージ判定(各指摘に対して順番に適用)

以下のフィルタを上から順に適用し、各指摘を **採用 / 軽微集約 / 除外** のいずれかにラベリングする。判定結果(理由つき)は内部で保持し、Step 5 のレポートで件数と除外理由を要約する。

#### A. スコープフィルタ(除外候補)
- 差分行(追加/変更行)に紐づかない指摘 → **除外**
- ファイル名が示されていない / 一般論で終わっている → **除外**
- 既存コード(差分外)の指摘 → **除外**(差分行に同じ問題が再生産されている場合のみ採用)

#### B. 根拠フィルタ(降格・除外候補)
- 「〜かもしれない」のみで具体的な失敗シナリオ・違反規約・読みにくさの根拠が無い指摘
  - severity が CRITICAL/IMPORTANT → **要確認 に降格**(severity は据え置きだが扱いを下げる)
  - severity が LOW → **除外**
- 推測ベースで動作確認が必要な指摘 → 「要検証」マーカーを付けて採用(必読扱いはしない)

#### C. 集約フィルタ(軽微集約)
- LOW の中で同種(命名・コメント・スタイル・整形)が同一ファイルに 3件以上 → **カテゴリ単位で集約**(例:「`foo.ts` の命名 LOW: 5件」)
- 異なるファイルでも同種テーマの LOW が 5件以上 → **テーマで集約**

#### D. 重要度の選別(採用ランク決定)
採用された指摘を以下の 3 ランクに振り分ける:

| ランク | 条件 |
| --- | --- |
| **必読(Must)** | CRITICAL 全件 / IMPORTANT のうち「共通指摘」または「具体的な失敗シナリオ・違反規約あり」 |
| **要確認(Should)** | 残りの IMPORTANT / B で降格された CRITICAL・IMPORTANT / 「要検証」マーカーつき |
| **軽微(Nice-to-fix)** | 採用された LOW(C で集約済みのものは集約形で表示) |

### 4.3 並べ替えと連番付与
- 各ランク内では「共通(Claude+Codex)」を先に、次に「Claude のみ」「Codex のみ」の順
- 同帰属内では severity 高 → 低、その後ファイルパス昇順
- 並べ替え確定後、各ランク内で 1 から連番を振る(`[必読 1]`、`[必読 2]`、`[要確認 1]` …)。この連番が Step 5 の見出しに使われる

### 4.4 トリアージ集計
レポートに載せる件数を計算しておく:
- 採用: 必読 a 件 / 要確認 b 件 / 軽微 c 件
- 集約: d 件(C により n 件 → m 件 に圧縮)
- 除外: e 件(理由内訳: スコープ外 e1 / 根拠弱 e2 / 重複統合済み e3)

### 4.5 レビュアー総評の統合

両者のサマリー原文(Claude subagent の戻り値末尾の `## サマリー` 節、Codex 出力末尾の `## サマリー` 節)を、オーケストレーター自身が **1本のテキスト** に融合する。レビュアー別に並べない。

融合方針:
- 両者が共通で挙げた論点は「両者が指摘」と地の文で示す(箇条書きの帰属ラベルとは別物。あくまで読み物としての強調)
- 片方しか挙げていない論点は採用するか取捨選択し、採用するなら根拠の強さに応じて文中で扱いを差別化する
- 文体は skill オーケストレーターの一人称(辛口・断定調)に揃える。原文の引用調を残さない
- 長さは 5〜8 行を目安。サマリー(`## 📝 サマリー`)と機械的な重複が出る場合はそちらに寄せて短縮する
- 片方のレビュアーが失敗して片側しか融合元がない場合、その旨を冒頭1文で明示してから融合する

---

## Step 5: ユーザーへの報告

**Step 4 のトリアージ結果に基づき、以下の階層で出力する**。生の指摘リストはそのまま流さない。
レビュアー別の総評も流さない(Step 4.5 で融合した1本のテキストに置き換える)。

大項目の H2 には視認性のため絵文字を付ける(下記テンプレ参照)。SEVERITY ラベル等の細部には付けない。

```markdown
# ブランチレビュー結果

## 📋 メタ情報
- branch: <branch> (local / remote)
- base: <base>(自動判定経路を 1 行で)
- merge-base: <sha (短縮)>
- 変更ファイル: N 件
- 追加/削除行: +X / -Y
- worktree: <WT_PATH>

## 📝 サマリー(3〜5行)
オーケストレーター自身の言葉で、ブランチ全体の状態を辛口に総括する。
「マージ可能か / ブロッカーは何か / どこが一番弱いか」を最低限カバー。

## 📊 トリアージ集計
- 必読(Must): a 件 / 要確認(Should): b 件 / 軽微(Nice-to-fix): c 件
- 集約: d 件(LOW を n→m 件にまとめ)
- 除外: e 件(スコープ外 e1 / 根拠弱 e2 / 重複統合 e3)
- 帰属: 共通 X 件 / Claude のみ Y 件 / Codex のみ Z 件

## 🚨 必読(Must)
ここはブロッカー候補。CRITICAL と、根拠の固い IMPORTANT のみ。
各指摘の見出しは `### [必読 N] <SEVERITY マーク> SEVERITY 指摘タイトル <帰属ラベル>` 形式（N は Step 4.3 で振った必読内の連番。1 から始まる）。
- 🔴 CRITICAL / 🟡 IMPORTANT / 🔵 LOW を必ず severity マークの先頭に付ける
- 複数件並べる場合は各指摘の末尾に水平線 `---` を入れて視覚的に分離する（最後の指摘の後は不要）

例:
### [必読 1] 🔴 CRITICAL 認証トークンが平文ログに出力される <共通(Claude+Codex)>
- ファイル: `path/to/file:line`
- 問題: ...
- 根拠: ...
- 修正方針: マスキング関数経由でログ出力する
- 修正例:
  ```diff
  - logger.info(`token=${token}`)
  + logger.info(`token=${maskToken(token)}`)
  ```

---

### [必読 2] 🟡 IMPORTANT API エラー時に nil を返している <Claude のみ>
- ...

## ⚠️ 要確認(Should)
判断が分かれそうな IMPORTANT、根拠が弱めだが見落とせない指摘、要検証マーカーつき。
見出しは `### [要確認 N] <SEVERITY マーク> SEVERITY 指摘タイトル <帰属ラベル>` 形式（N は要確認内の連番）。
各指摘は必読と同じフォーマットで列挙してよい（必読より簡潔でよい）。複数件並べる場合は `---` で区切る。

例:
### [要確認 1] 🔴 CRITICAL 競合条件の可能性（要検証） <Codex のみ>
- ...

---

### [要確認 2] 🟡 IMPORTANT テスト欠如 <共通(Claude+Codex)>
- ...

## 🔧 軽微(Nice-to-fix)
LOW のみ。集約したものは集約形で出す。集約形（箇条書き）にはランク番号を付けず、`---` でも区切らない。
- `foo.ts` の命名 LOW: 5 件 — 例: `xxx → yyy`、`aaa → bbb`(代表 2〜3 件のみ)
- スタイル LOW(全体): 8 件 — 主に整形・末尾セミコロン

集約せず個別に `###` 見出しで出す LOW は `### [軽微 N] 🔵 LOW タイトル <帰属>` 形式とし、複数並ぶ場合は `---` で区切る:

### [軽微 1] 🔵 LOW 変数名 `tmp` が文脈を表していない <Codex のみ>
- ファイル: `path/to/file:line`
- ...

## 🗑️ トリアージで除外した指摘
件数とカテゴリだけ報告(タイトル一覧は不要、ノイズになる):
- スコープ外(差分行に紐づかない): e1 件
- 根拠が弱い LOW: e2 件
- 既存コード由来(差分外): e3 件
- 重複統合済み: e4 件

## 💬 レビュアー総評
Step 4.5 で融合した 1本のテキストをここに出す。Claude / Codex を H3 で分けない。
両者の観点を吸収しつつ、skill オーケストレーター視点の辛口総評として書く。

## 🎯 次アクション候補
- 修正したい場合: `/spec-driven-feature-dev` か個別指示でフォローアップ
- 特定指摘を深掘りしたい場合: `/codex-second-opinion`
- 除外した指摘の詳細を見たい場合: その旨伝えれば、再実行せずに保留中のトリアージ生データから抽出して提示する(同一会話内のみ)
```

### レポート時の心得
- **必読セクションは短く、密度高く**。CRITICAL でも 5 件超えるなら「最重要 3 件」を上に置く
- **軽微セクションは件数で殴らない**。10 件越えたら必ずカテゴリ集約形にする
- 「両者共通」はユーザーが優先確認すべきなので、各セクションで先頭に置く
- `.gitignore` に `.worktrees/` 未登録なら、最後に警告 1 行を添える

---

## Step 6: worktree 後始末

`AskUserQuestion` で 3 択を提示する:

- **削除**: `git worktree remove "${WT_PATH}"`(失敗したら `--force` 提案を再度 `AskUserQuestion`)
- **残す**: パスとブランチを最終出力に再掲(後で cd して使えるように)
- **詳細を見る**: `git worktree list` を表示してから再度この質問

---

## Step 7: 一時ファイルのクリーンアップ

skill 終端で必ず実行:

```bash
rm /tmp/review_branch_diff_${SID}.patch \
   /tmp/review_branch_stat_${SID}.txt \
   /tmp/review_branch_files_${SID}.txt \
   /tmp/review_branch_codex_${SID}.txt
```

`SID` ごとに一意なので、並列実行や途中失敗で衝突しない。

---

## エッジケース早見表

| ケース | 挙動 |
| --- | --- |
| 差分 0 行 | 早期終了、worktree 後始末だけ案内 |
| diff > 5000 行 | `AskUserQuestion` で続行可否確認 |
| `BRANCH == BASE` | エラー終了 |
| リモートにしか無い | `git fetch --prune origin` 後に worktree 作成 |
| ローカル/リモート同名で内容差 | ローカル優先、最終報告に差の有無を 1 行添える |
| detached HEAD で worktree 作成 | 報告冒頭に明記 |
| `.worktrees/` が `.gitignore` 未登録 | 警告 1 行のみ(編集はしない) |
| Codex / Claude の片方失敗 | もう片方だけで報告し、失敗側を「未取得」と明示 |
| 両方失敗 | エラー報告して worktree 後始末へ |
