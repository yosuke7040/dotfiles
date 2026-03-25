---
name: codex-second-opinion
description: Claude Codeで進めている設計・実装修正・不具合調査について、Codexに第三者レビューまたは議論を依頼するskill。Codexへの送信・実行・結果取得・ユーザーへの報告まで一貫して行う。設計変更の妥当性確認、Claude提案への不安、複数案の比較、長い議論で解決しない問題、本番影響がある変更、セキュリティや性能リスクがある場合に積極的に使うこと。ユーザーが「Codexにも聞いてみたい」「別の視点が欲しい」「本当にこれで大丈夫か確認したい」「第三者レビュー」「Codexと議論して」「反論して」などと言ったときも必ず使う。
---

あなたは、Claude Code で進めている作業について、Codex に第三者レビューまたは議論を依頼し、その結果をユーザーに報告する役割を担う。

**依頼文を作って終わりにしてはいけない。必ず Codex を実行し、結果をユーザーに届けること。**

---

## モードの判定

まず、ユーザーの意図からモードを判断する。

- **レビューモード**（デフォルト）: Codex に一方向でレビューを依頼し、結果をそのままユーザーに報告する。
- **議論モード**: ユーザーが「議論して」「反論して」「Claudeの意見も聞きたい」「ディベートして」と言った場合。Claude が自分の立場を明確にし、Codex と複数ラウンドの往復議論を行い、全てのやり取りをリアルタイムでCLIに表示する。

---

## Step 1: 情報の整理

以下の項目を埋める。わからないものは「不明」と書く。

### request_type（1つ選ぶ）
- `design_review` — 設計方針や変更の妥当性確認
- `fix_review` — 修正差分の安全性・妥当性確認
- `root_cause_review` — 根本原因の見立て確認
- `stuck_consultation` — 長い議論で解決しない問題の相談
- `alternative_review` — 複数案の比較・選択支援

### 収集する情報
- **objective**: この依頼で達成したいことを1〜3文で
- **established_facts**: コードやログなど確認済みの事実
- **claude_proposal**: Claudeが提案・実施した内容（事実と仮説を分けて）
- **unresolved_points**: まだ解決していない論点
- **constraints**: 制約条件・変更不可箇所・運用条件
- **diff_summary**: 変更差分の要点（関連ファイル名も）
- **questions_for_codex**: 3〜7個の具体的な質問（「〜の場合、〜はリスクになりますか？」の形式）

---

## Step 2: Codex レビュー依頼文の組み立て

以下のテンプレートで依頼文を作成する。

# Codex Review Request

## Request Type
{request_type}

## Objective
{objective}

## Established Facts
{established_facts}

## Claude Proposal
{claude_proposal}

## Unresolved Points
{unresolved_points}

## Constraints
{constraints}

## Diff Summary
{diff_summary}

## Questions for Codex
{questions_for_codex}

## Review Instructions
Please review this as a third-party reviewer, not as an implementer.
Do not assume Claude's proposal is correct.

Return your answer in this structure:
1. Conclusion
2. Valid Points
3. Concerns
4. Alternatives
5. Priority Checks
6. Recommended Actions
7. Suggested Direction Back to Claude Code

---

## Step 3: Codex の実行

### モデル指定について
- **デフォルト（推奨）**: `~/.codex/config.toml` の設定（通常 `gpt-5.4` + `medium` reasoning）をそのまま使う。`-m` オプションなしで実行。
- ユーザーが特定モデルを指定した場合: `-m <model-id>` を付ける（例: `-m gpt-5.4`）。
- `gpt-5.4-medium` のような複合指定は存在しない。モデルと reasoning effort は別設定。

### 実行コマンド

`-o` オプションで最後のメッセージだけをファイルに書き出す。これにより出力量に関わらず確実に最終回答を取得できる。

bash
cat << 'PROMPT' | codex exec --ephemeral -o /tmp/codex_result.txt -
{依頼文の内容}
PROMPT
cat /tmp/codex_result.txt

- `--ephemeral`: セッションファイルを `~/.codex/sessions/` に保存しない（ファイル蓄積防止）
- `-o /tmp/codex_result.txt`: 最終回答のみをこのファイルに書き出す
- Codex がコードを実際に読んで調査するため、カレントディレクトリはプロジェクトルートであること

---

## Step 4: 結果の整理と報告

Codex の回答を取得したら、以下の形式でユーザーに報告する：

## Codex レビュー結果

### 総評
[Conclusion の内容]

### 妥当な指摘
[Valid Points]

### 懸念・誤りの指摘
[Concerns]

### 代替案・補足
[Alternatives]

### 優先度の修正
[Priority Checks]

### 推奨アクション
[Recommended Actions]

---
Claude からのコメント: [Codex の回答を受けて、自分の見解との差分・同意点・修正すべき点を簡潔に]

**レビューモードはここで完了。**

---

## 議論モードの手順

ユーザーが議論・ディベートを求めた場合は以下のフローで進める。全てのやり取りをリアルタイムでCLIに出力すること。

### Phase 0: Claude の立場を表明する

Codex に送る前に、Claude 自身の見解をユーザーに示す。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【Claude の立場】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[トピック・論点を1文で]

**Claude の見解:**
[自分の意見を明確に。「〜だと考える」「〜が正しいと判断する」の形で]

**根拠:**
- [具体的なエビデンス・コード・ログ・技術的事実]
- [理由・論拠]

**留保事項（自信がない点）:**
- [正直に不確かな部分を列挙]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### Phase 1: Round 1 — Codex へ送信

依頼文に Claude の立場を追加して送信する。

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【Round 1: Codex へ送信中...】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

依頼文の末尾に以下を追加する:

## Claude's Position (for debate)
Claude has the following view on this topic:
{Claude の見解と根拠}

Please evaluate Claude's position directly. State clearly where you agree and where you disagree, with specific reasons. Do not be diplomatic — be direct.

以下のコマンドで Codex を実行し、回答を取得する。ラウンドごとに出力ファイルを上書きしてよい:

bash
cat << 'PROMPT' | codex exec --ephemeral -o /tmp/codex_debate_r1.txt -
{依頼文 + Claude の立場を付加した内容}
PROMPT
cat /tmp/codex_debate_r1.txt

取得した回答を**一切要約せずそのまま**表示する。長くても分割して全文出力すること:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【Round 1: Codex の回答】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{Codex の回答を省略・要約せずそのまま全文表示。
長い場合は複数メッセージに分けて出力してよい。}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Codex の回答を全文出力し終えた後に**、Claude の評価・反論に移る。順序を逆にしてはいけない。

### Phase 2: Claude の評価と反論判断

Codex の回答を読み、各論点を評価する:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【Claude の評価】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**同意する点:**
- [具体的に。なぜ同意するか]

**反論したい点:**
- [論点]: [Codex の主張] → [Claude の反論] (根拠: [具体的なエビデンス])

**Codex が指摘した見落とし（受け入れる）:**
- [正直に認める]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

反論すべき点がある場合は Round 2 に進む。全て同意した場合は終了。

### Phase 2（Round 2 が必要な場合）: 反論を送信

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【Round 2: Claude の反論を Codex へ送信中...】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

bash
cat << 'PROMPT' | codex exec --ephemeral -o /tmp/codex_debate_r2.txt -
{前ラウンドまでの会話履歴 + Claude の反論}
PROMPT
cat /tmp/codex_debate_r2.txt

Round 2 の送信内容:

# Debate Round 2 - Claude's Counter-Arguments

## Original Context
{元の依頼文の要約}

## Round 1 Summary
Claude's position: {Claude の立場要約}
Codex's Round 1 response: {Codex の回答要約}

## Claude's Counter-Arguments
{各反論点を、具体的なエビデンスと共に列挙}

## Questions for Round 2
1. [反論に対する Codex の見解を問う具体的な質問]
2. ...

Please respond to each counter-argument specifically.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【Round 2: Codex の回答】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

{Codex の回答を省略・要約せずそのまま全文表示。
長い場合は複数メッセージに分けて出力してよい。}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**Codex の回答を全文出力し終えた後に**、Claude の評価・反論に移る。

### Phase 3: 議論のまとめ（最大 10 ラウンドで終了）

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
【議論のまとめ】
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

**合意に至った点:**
- [Claude と Codex が共通して認識した事実・結論]

**見解の相違が残った点:**
- [論点]: Claude は [〜] と考える。Codex は [〜] と考える。理由の違い: [〜]

**ユーザーへの推奨:**
[両者の議論を踏まえた上で、ユーザーがどう判断すべきかを提示。
どちらが正しいかを断定するのではなく、判断材料を整理する]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

---

## 反論のルール（議論モード）

- **事実・コードに基づいて反論する**: 「そう思う」ではなく「このコードの〜行を見ると〜」「Python の仕様では〜」のように具体的に。
- **間違いは素直に認める**: Codex が正しい指摘をした場合、「その点は正しい」と認めた上で議論を続ける。プライドより正確さを優先する。
- **断定と推測を分ける**: 確かな事実と推測は明示的に区別する。
- **10 ラウンドで終了**: 上限に達したらまとめに移る。それ以前でも全て同意に至った場合は終了してよい。

---

## 注意事項

- **実行を忘れない**: Step 3 まで必ず実行すること。依頼文を生成して満足しない。
- **会話全文をそのまま貼らない**: 要点を圧縮して送る。
- **事実と仮説を混ぜない**: 依頼文内で明示的に区別する。
- **質問は曖昧にしない**: 「どう思いますか？」より「〜の場合、〜はリスクになりますか？」。
- **Codex に実装させない**: あくまでレビュアー・議論相手として扱う。
