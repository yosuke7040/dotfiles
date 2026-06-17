---
name: review-branch
description: 任意のブランチ/PR URL とデフォルトブランチの差分を、Claude と Codex の 2エージェントで並列に辛口レビューし、結果を統合・整理して報告する skill。単一リポジトリだけでなく、submodule 集約リポジトリ(handy-root 等)の submodule PR、および複数 submodule に跨る機能横断レビューにも対応する。レビュー専用に git worktree を切ってから走らせるため、現在の作業ツリーを汚さない。修正は行わず、指摘の整理と報告までを担当する。
argument-hint: "[<pr-url> ... | <submodule>:<branch> | <branch>] [--base <base>]"
allowed-tools: Read, Grep, Glob, Bash(git:*), Bash(gh:*), Bash(cat:*), Bash(date:*), Bash(mkdir:*), Bash(ls:*), Bash(rm:*), Bash(uuidgen:*), Bash(tr:*), Bash(head:*), Bash(basename:*), Bash(wc:*), Bash(awk:*), Bash(sed:*), Bash(grep:*), Bash(echo:*), Bash(test:*), Bash(codex:*), Agent
---

# review-branch

Claude と Codex の 2エージェントによる **辛口** ブランチ/PR レビュー skill。
git worktree を切ってからレビューするので、現在の作業ツリーを汚さない。
単一リポジトリと、submodule 集約リポジトリ(handy-root 等)の両方に対応する。

## 目的とスコープ

### やること
- 指定 PR URL / ブランチのための git worktree 作成（対象が submodule の場合は submodule 内に作る）
- そのブランチと base(既定: PR の baseRefName、または `main` / `origin/HEAD`)との差分取得
- Claude(`general-purpose` subagent)と Codex(`codex exec`)を並列に起動
- 両者の指摘を統合・整理してユーザーへ報告
- 複数 PR URL が渡された場合は、PR ごとに並列レビュー後、**PR 間整合性レビュー**を追加で 1ラウンド回す

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

## Step 0: 入力モード判定

引数の形から動作モードを決める。`TARGETS` という配列を作り、後段は配列の各要素に対して同じ処理を回す（単一要素なら従来通り、複数要素なら機能横断モードとして PR 間整合性レビューを追加実行する）。

各 `TARGET` の中身は以下の構造を持つ:

```
TARGET = {
  KIND:            "pr" | "branch",                # 入力の種類
  REPO_ROOT:       <skill が呼ばれたリポジトリ root>,  # 全TARGET 共通
  TARGET_REPO_PATH: <git 操作の発行先パス>,            # root か submodule path
  TARGET_LABEL:    <報告に出す名前>,                  # 例: "handy-front" / "(root)"
  BRANCH:          <ブランチ名>,
  BRANCH_KIND:     "local" | "remote",
  BASE:            <比較先ブランチ名>,
  PR_NUMBER:       <PR番号 | 空>,
  PR_URL:          <PR URL | 空>,
  PR_TITLE:        <PRタイトル | 空>,
  PR_CHANGED_FILES: <PR の changedFiles 数 | 空>,    # Step 2 末尾の sanity check で使う
  IS_FORK:         true/false,                     # PR 元が別 fork かどうか
}
```

### 0.1 引数の形式判定

引数を順に見て、以下の優先順位で分類する:

| 引数の形 | 例 | 解釈 |
|---|---|---|
| `https://github.com/<owner>/<repo>/pull/<N>` | `https://github.com/handy-inc/handy-front/pull/1395` | **PR URL モード** |
| `<owner>/<repo>#<N>` | `handy-inc/handy-front#1395` | PR URL モード(短縮形) |
| `<submodule>:<branch>` | `handy-front:feature/foo` | **submodule 限定ブランチモード** |
| `<branch>` | `feature/foo` | **互換ブランチモード**(root リポジトリ) |
| `--base <ref>` | `--base develop` | base override(全 TARGET に適用) |

PR URL モードが 1個以上含まれていた場合、ブランチ系引数は基本受け付けない（混在は禁止、エラー終了）。

### 0.2 REPO_ROOT の確定

```bash
REPO_ROOT=$(git rev-parse --show-toplevel)
HAS_SUBMODULES=false
if [ -f "${REPO_ROOT}/.gitmodules" ]; then
  HAS_SUBMODULES=true
fi
```

### 0.3 PR URL モードの処理(引数ごとに繰り返し)

#### 0.3.1 URL のパース
正規表現で `<owner>/<repo>/<N>` を抽出。

#### 0.3.2 submodule への解決
- `${REPO_ROOT}/.gitmodules` を Read し、各 submodule の `path` と `url` を取り出す
- `url` 末尾の `.git` を除去し、`<owner>/<repo>` 形を抽出して引数の owner/repo と照合
- マッチした場合: `TARGET_REPO_PATH=${REPO_ROOT}/<submodule path>`、`TARGET_LABEL=<submodule path>`
- マッチしなかった場合:
  - `${REPO_ROOT}` 自身の `origin` remote が `<owner>/<repo>` と一致するか確認
  - 一致すれば `TARGET_REPO_PATH=${REPO_ROOT}`、`TARGET_LABEL="(root)"`
  - 一致しなければエラー終了。「この PR は handy-root および submodule のいずれにも属していません」とユーザーに伝え、`<owner>/<repo>` を別ディレクトリに clone する案を提示する（実行はしない）

#### 0.3.3 submodule の初期化保証
submodule が未初期化(`git submodule status -- <path>` の出力が `-` で始まる)の場合:
- `AskUserQuestion` で「初期化する / 中止する」を確認
- 初期化を選んだら `git submodule update --init -- <path>` を実行

#### 0.3.4 PR メタ情報の取得
```bash
gh pr view <N> --repo <owner>/<repo> \
  --json number,title,headRefName,baseRefName,headRepository,headRepositoryOwner,url,additions,deletions,changedFiles,isCrossRepository
```

ここから:
- `BRANCH = headRefName`
- `BASE = baseRefName`(`--base` 引数があればそちらで上書き)
- `IS_FORK = isCrossRepository`
- `PR_TITLE = title`
- `PR_CHANGED_FILES = changedFiles`(Step 2 末尾の sanity check で `gh pr view` の `additions`/`deletions`/`changedFiles` と突き合わせるため)

#### 0.3.5 PR ブランチと base の fetch

fork でも non-fork でも安全に取得できる `pull/<N>/head` を使う。**同時に base ブランチも fetch する**(submodule リポジトリの `origin` は親リポジトリの `git fetch` では更新されないため、ローカル `origin/<base>` が古いと Step 2 の merge-base がズレ、既に main に merged された他 PR の変更まで diff に混入する):

```bash
git -C "${TARGET_REPO_PATH}" fetch origin \
  "pull/${PR_NUMBER}/head:refs/heads/pr-${PR_NUMBER}-${SAFE_BRANCH}" \
  "${BASE}"
```

fetch に成功したら `BRANCH = pr-${PR_NUMBER}-${SAFE_BRANCH}`（worktree 作成時に使う一意名）、`BRANCH_KIND=local` 扱い。

### 0.4 submodule 限定ブランチモードの処理(`<submodule>:<branch>`)

- `<submodule>` を `.gitmodules` の path と照合し、存在しなければエラー終了
- `TARGET_REPO_PATH=${REPO_ROOT}/<submodule>`、`TARGET_LABEL=<submodule>`
- submodule 未初期化なら 0.3.3 と同じく確認の上で初期化
- branch の存在判定は 0.6 の手順で `TARGET_REPO_PATH` 上で実施
- PR 関連フィールドは空のまま

### 0.5 互換ブランチモードの処理(`<branch>`)

- `TARGET_REPO_PATH=${REPO_ROOT}`、`TARGET_LABEL="(root)"`
- branch の存在判定は 0.6 の手順で実施
- ただし `HAS_SUBMODULES=true` で root にも該当 branch が無かった場合:
  - 全 submodule を走査し、`git -C <submodule> rev-parse --verify refs/heads/<branch>` または `refs/remotes/origin/<branch>` で存在するものを集める
  - 1つだけ見つかった → 自動でその submodule に切り替え、`TARGET_LABEL` も上書きしてユーザーに「`<submodule>` の branch として解釈しました」と1行報告
  - 複数見つかった → `AskUserQuestion` で選択
  - どれも無ければエラー終了

### 0.6 branch の存在判定(共通)

```bash
if git -C "${TARGET_REPO_PATH}" rev-parse --verify --quiet "refs/heads/${BRANCH}"; then
  BRANCH_KIND=local
else
  git -C "${TARGET_REPO_PATH}" fetch --prune origin
  if git -C "${TARGET_REPO_PATH}" rev-parse --verify --quiet "refs/remotes/origin/${BRANCH}"; then
    BRANCH_KIND=remote
  else
    exit 1
  fi
fi
```

### 0.7 base の自動判定(優先順位)

PR URL モード以外で `--base` 未指定の時:
1. `git -C "${TARGET_REPO_PATH}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null` の末尾
2. `main`(実在確認)
3. `master`(実在確認)

どれも無ければエラー終了し、`--base` 明示を促す。

### 0.8 早期エラー

- `BRANCH == BASE` → エラー終了(差分が出ない)
- branch が見つからない → エラー終了
- PR URL モードと branch モードの混在 → エラー終了

---

## Step 1: worktree 作成(TARGET ごとに繰り返し)

### パス決定
```bash
SAFE_BRANCH=$(echo "${BRANCH}" | tr '/:' '__')
WT_PATH="${TARGET_REPO_PATH}/.worktrees/${SAFE_BRANCH}"
```

**重要**: worktree は必ず `TARGET_REPO_PATH` 配下に置く。root の `.worktrees/` ではなく、submodule の `.worktrees/` に作る。これにより worktree 内の `git` コマンドが正しい git dir(submodule の git)を参照する。

### 既存 worktree の扱い
```bash
if git -C "${TARGET_REPO_PATH}" worktree list --porcelain | awk '/^worktree /{print $2}' | grep -Fxq "${WT_PATH}"; then
  if [ -d "${WT_PATH}" ]; then
    REUSED=true
  else
    git -C "${TARGET_REPO_PATH}" worktree prune
    REUSED=false
  fi
fi
```

### 新規作成

**ローカルブランチの場合(PR URL モードで fetch 済みもここに該当):**
```bash
git -C "${TARGET_REPO_PATH}" worktree add "${WT_PATH}" "${BRANCH}"
```

**リモートのみの場合:**
```bash
git -C "${TARGET_REPO_PATH}" worktree add -b "${BRANCH}" "${WT_PATH}" "origin/${BRANCH}"
```

**ローカル/リモート両方に同名がある場合:** ローカル優先。最終報告に「ローカル `<branch>` とリモート `origin/<branch>` の差分の有無」を 1 行添える。

### `.gitignore` 確認(警告のみ)
`TARGET_REPO_PATH/.gitignore` に `.worktrees/` が未登録なら最終報告で警告する。submodule 側の `.gitignore` を見ること(root 側ではない)。

---

## Step 2: 差分取得(TARGET ごとに繰り返し)

merge-base 起点で取得し、base 側の更新を含めない。すべてのコマンドを `git -C "${WT_PATH}"` で発行する。

```bash
# 比較先 base を必ず最新化してから merge-base を計算する。
# ローカルの origin/<base> が古いと、merge-base がベース更新前の地点を指し、
# 既に main に merged された他 PR の変更まで diff に取り込んでしまう。
# (handy-root のような submodule リポジトリは親の git fetch では更新されない。
#  Step 0.3.5 で fetch していても、ブランチモードや時間差での再実行で古くなりうるため、
#  Step 2 でも防御的に再 fetch する。--quiet で出力を抑える)
git -C "${WT_PATH}" fetch origin "${BASE}" --quiet || true

# 比較リファレンスは origin/<base> を優先(ローカル base が古いことがある)
if git -C "${WT_PATH}" rev-parse --verify --quiet "refs/remotes/origin/${BASE}" >/dev/null; then
  BASE_REF="origin/${BASE}"
else
  BASE_REF="${BASE}"
fi

MERGE_BASE=$(git -C "${WT_PATH}" merge-base "${BASE_REF}" HEAD)

# SID は Step 3 で既に作っている前提。複数 TARGET の場合は SID に index suffix を付ける
git -C "${WT_PATH}" diff "${MERGE_BASE}..HEAD"            > /tmp/review_branch_diff_${SID}.patch
git -C "${WT_PATH}" diff --stat "${MERGE_BASE}..HEAD"     > /tmp/review_branch_stat_${SID}.txt
git -C "${WT_PATH}" diff --name-only "${MERGE_BASE}..HEAD" > /tmp/review_branch_files_${SID}.txt
```

### 早期終了・サイズチェック
- 差分 0 行 → 当該 TARGET をスキップ(複数 TARGET の場合は他を続行)。単一 TARGET の場合は Step 6 へ
- diff の総行数が **5000 行超** → `AskUserQuestion` で「続行 / 中止 / 主要ファイルだけに絞る」を確認
- 複数 TARGET 合算で 15000 行超 → 同様に `AskUserQuestion`

### Sanity check: PR の changedFiles と実 diff を突き合わせる(PR URL モード時)

`gh pr view` が返す `changedFiles` は GitHub 側で計算された PR の本来の差分件数。
自分が計算した diff の files 数とズレすぎていたら、base 取得が古い・別 ref を参照している・worktree が変な状態などの可能性が高い。

```bash
if [ -n "${PR_NUMBER}" ] && [ -n "${PR_CHANGED_FILES}" ]; then
  ACTUAL_FILES=$(wc -l < "/tmp/review_branch_files_${SID}.txt" | tr -d ' ')
  # 件数が小さい PR(変更 1〜3 ファイル)では 1 ファイル違うだけで「2倍」になるので、
  # min 件数 5 を下限にしてゆるく判定する
  LOWER=$(( PR_CHANGED_FILES > 5 ? PR_CHANGED_FILES / 2 : 1 ))
  UPPER=$(( PR_CHANGED_FILES > 5 ? PR_CHANGED_FILES * 2 : PR_CHANGED_FILES + 5 ))
  if [ "${ACTUAL_FILES}" -gt "${UPPER}" ] || [ "${ACTUAL_FILES}" -lt "${LOWER}" ]; then
    cat <<EOM
WARN: 計算 diff は ${ACTUAL_FILES} files ですが、PR は ${PR_CHANGED_FILES} files です。
  base ブランチが古い、もしくは別 ref を参照している可能性があります。
  - 期待 merge-base: origin/${BASE} の最新
  - 実 merge-base : ${MERGE_BASE}
EOM
    # AskUserQuestion で続行可否を確認:
    #   「続行 / 中止 / base を上書き(--base <ref> 相当を求める)」
  fi
fi
```

ズレが警告閾値を超えたら、レビューに進む前に **必ず AskUserQuestion で確認**する。
Codex/Claude を起動してから差分が間違っていたと気付いてもコストの無駄になる。

---

## Step 3: 並列レビュー実行(本skillの中核)

### セッション ID と複数 TARGET 対応

```bash
SID_BASE=$(uuidgen | tr '[:upper:]' '[:lower:]' | head -c 8)
```

単一 TARGET: `SID=${SID_BASE}`
複数 TARGET: `SID=${SID_BASE}_<index>`(0始まり)

### 実行順序

複数 TARGET の場合、Codex は **全 TARGET 分を一気に background 起動** してから Claude を順次 foreground で回す（Agent ツールが並列の場合は単一メッセージ内で並列発火する）。

1. TARGET ごとに Codex を `Bash run_in_background:true` で起動し、shell ID を全部記録
2. TARGET ごとに Claude(`general-purpose`)を Agent ツールで起動(複数 TARGET の場合は 1 メッセージで並列発火)
3. Agent が返ってきた順に結果を蓄積
4. `BashOutput` で各 Codex の終了を確認し、出力ファイルを Read

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

## 対象コンテキスト
- リポジトリ: ${TARGET_LABEL}${PR_URL:+ (PR: ${PR_URL})}
- PR タイトル: ${PR_TITLE:-N/A}
- branch: ${BRANCH} (${BRANCH_KIND})
- base: ${BASE} (merge-base: ${MERGE_BASE})
- 作業ツリー root: ${WT_PATH}(必要に応じて Read してよい。指摘は差分行のみ)
- このリポジトリは ${PARENT_CONTEXT_NOTE}

注: ${WT_PATH} は単一の git リポジトリです(${TARGET_LABEL})。**親ディレクトリや他 submodule のコードは読めません**。他リポジトリへの言及をする場合は推測である旨を明記してください。

### このリポジトリ固有の規約
作業ツリー root 配下に `.claude/CLAUDE.md` または `.claude/rules/` がある場合、必ず読んでください(命名規則・型運用・テスト方針などを含む)。指摘はその規約に整合しているかを優先的に評価してください。

## 入力ファイル
- 差分: /tmp/review_branch_diff_${SID}.patch
- 統計: /tmp/review_branch_stat_${SID}.txt
- 変更ファイル一覧: /tmp/review_branch_files_${SID}.txt

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

`PARENT_CONTEXT_NOTE` は TARGET の素性に応じて以下を埋め込む:
- root リポジトリ単体: 「単独リポジトリです」
- submodule リポジトリ(handy-root 等の配下): 「親 `handy-root` の submodule の一つです。proton(API契約) → handy(バックエンド) → handy-front(フロント) の依存方向があります」
- 機能横断モードの一員: 上記に加えて「同じ機能を構成する別 submodule の PR も並列でレビュー中です。本レビューでは自リポジトリ内の指摘に集中し、他 submodule との整合性は別ラウンドで扱われます」

### Claude(general-purpose subagent)起動

`Agent` ツールで `subagent_type: "general-purpose"` を指定し、以下と同等の `prompt` を渡す。複数 TARGET の場合は単一メッセージで複数 Agent を並列発火する。

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

## 対象コンテキスト
- リポジトリ: ${TARGET_LABEL} ${PR_URL ? "(PR: " + PR_URL + ")" : ""}
- PR タイトル: ${PR_TITLE or "N/A"}
- branch: ${BRANCH} (${BRANCH_KIND})
- base: ${BASE} (merge-base: ${MERGE_BASE})
- 作業ツリー root: ${WT_PATH}(必要に応じて Read してよい。指摘は差分行のみ)
- このリポジトリの位置づけ: ${PARENT_CONTEXT_NOTE}

**${WT_PATH} は単一の git リポジトリです**。親ディレクトリや他 submodule のコードは worktree からは見えません。他リポジトリのコードに言及する必要がある場合は推測である旨を明記してください。

### このリポジトリ固有の規約
作業ツリー root 配下に `.claude/CLAUDE.md` または `.claude/rules/` があれば必ず読んでください。命名規則・型運用・テスト方針・コンポーネント設計指針などを含むため、指摘はその規約への整合を優先的に評価してください。

## 入力
- 差分ファイル: /tmp/review_branch_diff_${SID}.patch
- 統計ファイル: /tmp/review_branch_stat_${SID}.txt
- 変更ファイル一覧: /tmp/review_branch_files_${SID}.txt

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
- 両方失敗 → 当該 TARGET をエラー扱い。複数 TARGET の場合は他 TARGET の結果は採用し、報告で当該 TARGET を「レビュー失敗」と明示

---

## Step 3.5: PR 間整合性レビュー(複数 TARGET 時のみ)

複数 PR が機能横断で渡された場合に限り、追加で 1 ラウンド回す。proton/handy/handy-front のように依存関係のある submodule の整合性ズレを拾う目的。

### 入力
- 各 TARGET の `/tmp/review_branch_diff_${SID}.patch` 全部
- 各 TARGET の `TARGET_LABEL`, `PR_TITLE`, `PR_URL`, branch/base 情報

### 実行
Codex を 1 本 background 起動し、全 diff を結合した一時ファイル `/tmp/review_branch_cross_${SID_BASE}.patch` を入力にする。プロンプト要点:

```
これは複数 PR を横断する機能横断レビューです。各 PR は同じ機能の異なるレイヤを実装しています。

依存方向(handy-root プロダクトの場合):
  proton / proton-sch (API契約) → handy / schema (バックエンド) → handy-front (フロント)

## あなたの仕事
各 PR の中身そのものではなく、PR 同士の整合性のみを評価してください。具体的には:
- API契約のズレ: proton で追加された rpc/message を handy が実装しているか、handy-front が正しく呼んでいるか
- 型の不整合: proto 型と DB スキーマ、TypeScript 型のミスマッチ
- 命名の不整合: 同じ概念に対して PR 間で命名が割れていないか
- エンドポイント/権限の不整合: バックエンドが要求する権限とフロントの利用者ロールが一致しているか
- スキーマ移行の順序: schema PR が先に merge されないと handy がコンパイル/動作しない、等
- データフローの欠落: 一方が送信しているが他方が受信していない情報

各 PR 単体の問題は別レビュアーが扱うので、ここでは扱わない。「整合性に関する」指摘のみを出す。

## 出力フォーマット
通常のレビュー指摘と同じだが、各指摘に **関係 PR** フィールドを追加し、複数 PR を `,` 区切りで列挙する。

例:
### 🔴 CRITICAL `ListReportsV2` の戻り値型が proton 定義と handy 実装でズレている
- **関係 PR**: handy-inc/handy#234, handy-inc/handy-front#1395
- **問題**: ...
- **根拠**: ...
- **修正方針**: ...
- **修正例**: ...
```

### 失敗時
PR 間整合性レビューが失敗しても致命的ではない。報告で「整合性ラウンド: 失敗(本文末に詳細)」と明記して続行する。

---

## Step 4: 結果統合とトリアージ(TARGET ごとに実施)

サブエージェントの生レビューはここで必ず処理する。**ユーザーに渡すのはトリアージ後のレポートだけ**。複数 TARGET の場合は TARGET ごとに 4.1〜4.5 を実行し、最後に 4.6 で全体総評を作る。

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

### 4.5 レビュアー総評の統合(TARGET ごと)

両者のサマリー原文(Claude subagent の戻り値末尾の `## サマリー` 節、Codex 出力末尾の `## サマリー` 節)を、オーケストレーター自身が **1本のテキスト** に融合する。レビュアー別に並べない。

融合方針:
- 両者が共通で挙げた論点は「両者が指摘」と地の文で示す(箇条書きの帰属ラベルとは別物。あくまで読み物としての強調)
- 片方しか挙げていない論点は採用するか取捨選択し、採用するなら根拠の強さに応じて文中で扱いを差別化する
- 文体は skill オーケストレーターの一人称(辛口・断定調)に揃える。原文の引用調を残さない
- 長さは 5〜8 行を目安。サマリー(`## 📝 サマリー`)と機械的な重複が出る場合はそちらに寄せて短縮する
- 片方のレビュアーが失敗して片側しか融合元がない場合、その旨を冒頭1文で明示してから融合する

### 4.6 全体総評(複数 TARGET 時のみ)

各 TARGET の総評と Step 3.5 の整合性レビュー結果を踏まえ、機能全体としての評価を 5〜8 行で書く。
- 機能としてマージ順序の制約はあるか(proton → handy → schema → handy-front 等)
- どの PR がブロッカーか
- 整合性ラウンドで重大な不整合が見つかったか

---

## Step 5: ユーザーへの報告

**Step 4 のトリアージ結果に基づき、以下の階層で出力する**。生の指摘リストはそのまま流さない。レビュアー別の総評も流さない(Step 4.5 で融合した1本のテキストに置き換える)。

大項目の H2 には視認性のため絵文字を付ける(下記テンプレ参照)。SEVERITY ラベル等の細部には付けない。

### 5.A 単一 TARGET の場合

```markdown
# ブランチレビュー結果

## 📋 メタ情報
- 対象: <TARGET_LABEL>(<PR_URL があれば PR URL も>)
- PR タイトル: <PR_TITLE があれば>
- branch: <branch> (local / remote)
- base: <base>(自動判定経路を 1 行で)
- merge-base: <sha (短縮)>
- 変更ファイル: N 件 / 追加・削除行: +X / -Y
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

## 🔧 軽微(Nice-to-fix)
LOW のみ。集約したものは集約形で出す。集約形（箇条書き）にはランク番号を付けず、`---` でも区切らない。
- `foo.ts` の命名 LOW: 5 件 — 例: `xxx → yyy`、`aaa → bbb`(代表 2〜3 件のみ)
- スタイル LOW(全体): 8 件 — 主に整形・末尾セミコロン

集約せず個別に `###` 見出しで出す LOW は `### [軽微 N] 🔵 LOW タイトル <帰属>` 形式とし、複数並ぶ場合は `---` で区切る。

## 🗑️ トリアージで除外した指摘
件数とカテゴリだけ報告(タイトル一覧は不要、ノイズになる):
- スコープ外(差分行に紐づかない): e1 件
- 根拠が弱い LOW: e2 件
- 既存コード由来(差分外): e3 件
- 重複統合済み: e4 件

## 💬 レビュアー総評
Step 4.5 で融合した 1本のテキストをここに出す。Claude / Codex を H3 で分けない。

## 🎯 次アクション候補
- 修正したい場合: `/spec-driven-feature-dev` か個別指示でフォローアップ
- 特定指摘を深掘りしたい場合: `/codex-second-opinion`
- 除外した指摘の詳細を見たい場合: その旨伝えれば、再実行せずに保留中のトリアージ生データから抽出して提示する(同一会話内のみ)
```

### 5.B 複数 TARGET の場合(機能横断モード)

トップに全体俯瞰、続けて TARGET ごとのセクション、最後に PR 間整合性。

```markdown
# 機能横断レビュー結果

## 📋 全体メタ情報
- 対象 PR / ブランチ数: N
- 各対象:
  - 1. <TARGET_LABEL_1> — <PR_TITLE_1> (<PR_URL_1>) — 変更 +A1 / -B1, files C1
  - 2. <TARGET_LABEL_2> — ...
  - ...
- 共通 base: <base>(全 TARGET 共通の場合のみ表示)
- 推定マージ順序: proton → handy → schema → handy-front (依存方向に基づく機械判定)

## 📝 全体サマリー(5〜8行)
Step 4.6 の全体総評をここに出す。機能としてマージ可能か / どの PR がブロッカーか / 一番弱いレイヤはどこか。

## 📊 全体トリアージ集計
PR 別 + 整合性ラウンドの合算:

| 対象 | 必読 | 要確認 | 軽微 | 整合性 |
| --- | --- | --- | --- | --- |
| handy-front #1395 | 2 | 5 | 3 (集約後) | - |
| handy #234 | 1 | 3 | 2 | - |
| 🔗 整合性 | 1 | 2 | - | - |

---

## 🔗 PR 間整合性(Step 3.5)
整合性ラウンドで採用された指摘のみ。各指摘の見出しは `### [整合性 N] <SEVERITY マーク> SEVERITY タイトル` 形式。**関係 PR** フィールドを必ず付ける。

### [整合性 1] 🔴 CRITICAL `ListReportsV2` の戻り値型が proton 定義と handy-front 実装でズレている
- 関係 PR: handy-front#1395, handy#234
- ファイル(複数): `handy-front/.../listReports.ts`, `handy/.../reports.go`
- 問題: ...
- 根拠: ...
- 修正方針: ...
- 修正例: ...

---

## 📦 <TARGET_LABEL_1>(<PR URL_1>)
ここから先は単一 TARGET レポートと同じ構造。ただし H2 は使わず H3 から始める:

### 📝 サマリー
### 📊 トリアージ集計
### 🚨 必読(Must)
### ⚠️ 要確認(Should)
### 🔧 軽微(Nice-to-fix)
### 🗑️ 除外
### 💬 レビュアー総評

---

## 📦 <TARGET_LABEL_2>(<PR URL_2>)
...

---

## 🎯 次アクション候補
- 機能全体の不整合を直す場合: `/spec-driven-feature-dev`
- 特定 PR を深掘りしたい場合: PR URL を 1本だけ渡して再実行
- 除外した指摘の詳細を見たい場合: その旨伝えれば、再実行せずに保留中のトリアージ生データから抽出して提示する(同一会話内のみ)
```

### レポート時の心得
- **必読セクションは短く、密度高く**。CRITICAL でも 5 件超えるなら「最重要 3 件」を上に置く
- **軽微セクションは件数で殴らない**。10 件越えたら必ずカテゴリ集約形にする
- 「両者共通」はユーザーが優先確認すべきなので、各セクションで先頭に置く
- 各 TARGET の `.worktrees/` が `.gitignore` 未登録なら、最後に警告 1 行を添える
- 複数 TARGET の場合、整合性ラウンドが失敗していたらレポート末尾で必ず明示する

---

## Step 6: worktree 後始末

TARGET ごとに `AskUserQuestion` で 3 択を提示する(複数 TARGET の場合は全 TARGET をまとめて 1 質問で「全部削除 / 全部残す / 個別に選ぶ」を提示し、3つ目を選ばれた時のみ TARGET ごとに再質問):

- **削除**: `git -C "${TARGET_REPO_PATH}" worktree remove "${WT_PATH}"`(失敗したら `--force` 提案を再度 `AskUserQuestion`)
- **残す**: パスとブランチを最終出力に再掲(後で cd して使えるように)
- **詳細を見る**: `git -C "${TARGET_REPO_PATH}" worktree list` を表示してから再度この質問

---

## Step 7: 一時ファイルのクリーンアップ

skill 終端で必ず実行。複数 TARGET の場合は全 SID 分:

```bash
# 主ファイル(Step 2 で必ず生成済み = 存在することが確定している)
rm /tmp/review_branch_diff_${SID}.patch \
   /tmp/review_branch_stat_${SID}.txt \
   /tmp/review_branch_files_${SID}.txt \
   /tmp/review_branch_codex_${SID}.txt

# 整合性ラウンド分(複数 TARGET 時のみ生成。単一 TARGET 時は存在しないので存在チェックで分岐):
for f in \
  /tmp/review_branch_cross_${SID_BASE}.patch \
  /tmp/review_branch_cross_codex_${SID_BASE}.txt
do
  [ -e "$f" ] && rm "$f"
done
```

`SID` ごとに一意なので、並列実行や途中失敗で衝突しない。

### `rm` を組み立てるときの厳守事項

- **`rm -f` / `rm -rf` を反射的に付けない**。`-f` はファイル不在も権限不足もまとめて握りつぶすため、削除すべきファイルが消えていない異常に気付けなくなる
- 「存在しないこともある」ファイルは `-f` で握り潰すのではなく、上の整合性ラウンド分のように `[ -e "$f" ] && rm "$f"` で **明示的に存在チェック** を書く
- `2>/dev/null || true` のような **エラー黙殺パターンも同じ理由で禁止**(`-f` と等価に害がある)
- prompt テンプレ実行時にこのルールが書かれていなくても、AI 側の判断で `-f` は外す

---

## エッジケース早見表

| ケース | 挙動 |
| --- | --- |
| 差分 0 行 | 当該 TARGET をスキップ。単一 TARGET なら早期終了し worktree 後始末だけ案内 |
| diff > 5000 行(単一) / 合算 > 15000 行 | `AskUserQuestion` で続行可否確認 |
| `BRANCH == BASE` | 当該 TARGET をエラー扱い |
| リモートにしか無いブランチ | `git -C "${TARGET_REPO_PATH}" fetch --prune origin` 後に worktree 作成 |
| PR が fork から来ている | `git -C "${TARGET_REPO_PATH}" fetch origin pull/<N>/head:refs/heads/pr-<N>-...` で取得 |
| ローカル/リモート同名で内容差 | ローカル優先、最終報告に差の有無を 1 行添える |
| detached HEAD で worktree 作成 | 報告冒頭に明記 |
| TARGET 配下の `.worktrees/` が `.gitignore` 未登録 | 警告 1 行のみ(編集はしない) |
| Codex / Claude の片方失敗 | もう片方だけで報告し、失敗側を「未取得」と明示 |
| 両方失敗 | 当該 TARGET をエラー扱い。複数 TARGET なら他は続行 |
| PR URL の owner/repo が root にも submodule にも該当しない | エラー終了。clone 案を提示(実行はしない) |
| submodule が未初期化 | `AskUserQuestion` で初期化可否を確認してから `git submodule update --init` |
| PR URL モードと branch モードの混在 | エラー終了 |
| Step 3.5 整合性ラウンドが失敗 | 続行。レポート末尾で明示 |
| `<branch>` が root に無く複数 submodule に存在 | `AskUserQuestion` で選択 |
