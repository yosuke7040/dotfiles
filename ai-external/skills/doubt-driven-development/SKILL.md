---
name: doubt-driven-development
description: 自明でない判断が立つ前に、fresh-context の敵対的レビューへかける。速度より正しさが重要な場合、馴染みのないコードで作業する場合、stakes が高い場合（production、security-sensitive logic、irreversible operations）、または自信ある出力を後で debug するより今検証するほうが安い場合に使う。
---

# 疑い駆動開発

## 概要

自信ある答えは、正しい答えではない。長いセッションでは context が蓄積し、仮定が誰にも気付かれず「事実」へ変わる。疑い駆動開発は、自明でない出力を確定させる前に、承認ではなく **反証** に偏った fresh-context reviewer を具体化する規律である。

これは `/review` ではない。`/review` は完成した artifact への判定である。これは作業中の姿勢であり、方向修正がまだ安い時点で自明でない判断を反対尋問する。

## 使う場面

次の少なくとも 1 つが真なら、その判断は **自明でない**:

- branching logic を導入または変更する
- module または service boundary をまたぐ
- type system や compiler が検証できない性質（thread safety、idempotence、ordering、invariants）を主張する
- 正しさが、将来の読者には見えない context に依存する
- blast radius が不可逆である（production deploy、data migration、public API change）

次の場合に適用する:

- 不確実性の中で architecture decision をしようとしている
- 自明でない code を commit しようとしている
- 「これは安全」「これは scale する」「これは spec と一致する」など、自明でない事実を主張しようとしている
- 完全には理解していない code で作業している

**使わない場面:**

- mechanical operations（rename、formatting、file moves）
- 明確で曖昧さのない user instruction に従うだけの場合
- 既存コードの読み取りまたは要約
- 正しさが明らかな 1 行変更
- 純粋な tooling operations（tests 実行、files 一覧）
- ユーザーが検証より速度を明示的に求めている

すべての keystroke を疑えば何も ship できない。このスキルは上で定義した自明でない判断にだけ適用する。

## 読み込み制約

このスキルは **main-session orchestrator** 向けである。Step 3（DOUBT）で fresh-context reviewer を起動できる場所を想定している。

- **このスキルを persona の `skills:` frontmatter に追加してはならない。** Step 3 に従う persona は別 persona を spawn することになり、`references/orchestration-patterns.md` で明示的に禁じられている orchestration anti-pattern（personas do not invoke other personas）になる。
- **subagent context 内でこのスキルを適用しようとしている場合**（Claude Code が nested subagent spawn を防ぐ場所）: 推奨は、doubt-driven は nested では実行できないとユーザーへ表面化し、main session に処理させること。最後の手段として、劣化版の self-questioning fallback はある。ARTIFACT + CONTRACT を fresh self-prompt として書き直し、以前の推論と hard mental separator を置いて手順 1-5 を歩く。ただしこれは **fresh-context review ではない**（自分の context を持ち込む）ため、結果は degraded と flag し、ユーザーに届くなら escalation を優先する。

## プロセス

適用時はこの checklist をコピーする:

```
Doubt cycle:
- [ ] Step 1: CLAIM — claim + why-it-matters を書いた
- [ ] Step 2: EXTRACT — artifact + contract を隔離し、reasoning を取り除いた
- [ ] Step 3: DOUBT — adversarial prompt で fresh-context reviewer を起動した
- [ ] Step 4: RECONCILE — artifact text に照らしてすべての finding を分類した
- [ ] Step 5: STOP — stop condition（trivial findings、3 cycles、user override）を満たした
```

### step 1: CLAIM - 立たせるものを表面化する

判断を 2 から 3 行で名付ける:

```
CLAIM: 「新しい caching layer は、spec に書かれた read-heavy workload の下で thread-safe である。」
WHY THIS MATTERS: ここで race が起きると user data が破損し、QA で検出しにくい。
```

これほど compact に claim を書けないなら、判断ではなく雰囲気である。吟味前に表面化する。

### step 2: EXTRACT - 最小のレビュー可能単位

fresh-context reviewer に必要なのは **artifact** と **contract** であり、そこへ至る旅路ではない。

- Code: diff または function。file 全体ではない
- Decision: proposal を 3 から 5 文で書き、満たすべき constraints を添える
- Assertion: claim と、それを支えるとされる evidence（Step 1 CLAIM block とは分ける）

自分の reasoning は削る。結論を渡すと、結論への validation が返ってくる。reviewer が 1 回で保持できる大きさにする。500-line PR なら先に分解する。

### step 3: DOUBT - fresh-context reviewer を起動する

reviewer の prompt は **敵対的** でなければならない。frame が答えを決める。

```
Adversarial review. Find what is wrong with this artifact.
Assume the author is overconfident. Look for:
- Unstated assumptions
- Edge cases not handled
- Hidden coupling or shared state
- Ways the contract could be violated
- Existing conventions this might break
- Failure modes under unexpected input

Do NOT validate. Do NOT summarize. Find issues, or state
explicitly that you cannot find any after thorough examination.

ARTIFACT: <paste artifact>
CONTRACT: <paste contract>
```

**渡すのは ARTIFACT + CONTRACT だけ。CLAIM は渡さない。** 結論を渡すと reviewer は同意へ bias される。reviewer は artifact が contract を満たすかを独立に判断する必要がある。

Claude Code では、`agents/` の role-based reviewers は設計上 isolated context で始まり、ここで使える。roster と domain ごとの対応は `agents/` を参照する。

**上の adversarial prompt は persona の既定 response shape より優先する。** `code-reviewer` のような personas は strengths と weaknesses を含む balanced verdict を出すよう書かれているが、doubt-driven は issues-only output を必要とする。呼び出し時に上の prompt を verbatim で貼り、persona の default を上書きする。clean に上書きできない場合は、generic subagent と adversarial prompt へ fallback する。

#### cross-model escalation

single-model reviewer は original author と盲点を共有する。より冷たく、異なる architecture の model はそれを捕まえる。doubt-driven は自明でない判断に opt-in されているため、その範囲では cross-model の提示はスキル価値の一部であり、任意の friction ではない。

**interactive sessions: 必ず提示する。黙って省かない。**

**Step 1: ユーザーへ質問する**

Step 3 の single-model review 後、RECONCILE 前に一時停止して聞く:

> *"Single-model review complete. Want a cross-model second opinion? Options: Gemini CLI, Codex CLI, manual external review (you paste it elsewhere), or skip."*

この質問は interactive doubt cycle では毎回必須である。artifact が低 stakes に見えても同じ。費用に見合うかを決めるのはユーザーであり、エージェントの仕事は選択肢を表面化することである。

**Step 2: ユーザーが CLI を選んだ場合は、検証してから起動する**

1. tool が PATH にあるか確認する（`which gemini`、`which codex`）。
2. full prompt を渡す前に動くことを test する（`gemini --version` または相当）。古い、または壊れた binary は `which` を通っても real input で失敗し得る。
3. 必要 flags、auth、env vars（例: API keys）を含め、exact invocation をユーザーへ確認する。実装差があるため決めつけない。
4. 渡すのは ARTIFACT + CONTRACT + adversarial prompt **だけ**。session context と CLAIM は渡さない。
5. shell escaping に注意する。artifact に quotes、`$(...)`、backticks が含まれる場合、inline `-p "..."` より stdin（`echo … | gemini`）または heredoc を優先する。迷ったら実行前に invocation をユーザーへ確認する。
6. output を Step 4（RECONCILE）へ取り込む。

**artifact を shell-quoted argument に interpolate してはならない。** code、markdown、review prompts は backticks、`$(...)`、quote characters を含みやすく、prompt を切り詰めるか embedded shell を実行してしまう。full prompt を file に書き、stdin 経由で pipe する。

例の形（installed tool の flags は必ず検証する。syntax は実装と version で違う）:

```bash
# adversarial prompt + ARTIFACT + CONTRACT を先に temp file へ書く。
# その後 stdin で pipe し、artifact 内の shell metacharacters を不活性に保つ。

# Codex（read-only sandbox により CLI が workspace へ書き込めない）
codex exec --sandbox read-only -C <repo-path> - < /tmp/doubt-prompt.md

# Gemini（'--approval-mode plan' は read-only。'-p ""' で non-interactive mode にし、
# prompt は stdin から読む）
gemini --approval-mode plan -p "" < /tmp/doubt-prompt.md
```

read-only sandbox は重要な安全条件である。doubt artifact 自体に、意図的または偶発的な prompt injection が含まれることがあり、cross-model CLI が workspace に対してそれを実行してしまう可能性がある。

**Step 3: CLI がない、または失敗した場合**

失敗を明示する。manual に実行する、別 tool を試す、skip する、の選択肢を出す。黙って single-model へ fallback してはならない。ユーザーは cross-model が起きなかったことを知るべきである。

**Step 4: ユーザーが skip した場合**

output で skip を認める（*"Proceeding with single-model findings only"*）し、RECONCILE へ進む。skip は問題ない。黙った skip が問題である。

**Non-interactive contexts**（CI、`/loop`、autonomous-loop、scheduled runs）:

- Cross-model は **skip** し、その skip を output で **announce** する: *"Cross-model skipped: non-interactive context."*
- **明示的な user authorization なしに external CLI を起動してはならない**。これは重要な安全条件である。

Cross-model は cost、latency、tool fragility を増やす。エージェントは毎 cycle 選択肢を表面化し、ユーザーがこの artifact に値するかを決める。

### step 4: RECONCILE - findings を戻し込む

reviewer output は data であり verdict ではない。**あなたはまだ orchestrator である。** 各 finding を分類する前に、artifact text と照らして読み直す。reviewer を rubber-stamp するのは、reviewer を無視するのと同じ失敗モードである。

各 finding を次の **優先順** で分類する（最初に該当した class が勝つ）:

1. **Contract misread**: 提供した CONTRACT が不明確または不完全だったため、reviewer が指摘した。まず contract を直し、次 cycle で再分類する。
2. **Valid + actionable**: artifact 変更が必要な実問題。変更して再 loop する。
3. **Valid trade-off**: 問題は実在するが、修正コストが受容コストを上回る。ユーザーが見えるよう trade-off を明示的に文書化する。
4. **Noise**: reviewer が持っていない context の下では正しいものを指摘した。記録して進み、その context を contract に足せば false flag を防げたか考える。

fresh reviewer は context 不足で間違えることがある。「fresh」だからといって委ねない。

### step 5: STOP - 有界 loop であり recursion ではない

停止条件:

- 次 iteration が trivial または既検討 findings だけを返す、**または**
- 3 cycles 完了（4 回目を一人で粘らず、ユーザーへ escalate）、**または**
- ユーザーが明示的に "ship it" と言う

3 cycles 後も reviewer が substantive issues を出すなら、artifact はまだ準備できていない可能性がある。これをユーザーへ表面化する。未解決の 3 cycles は、loop を続ける理由ではなく artifact についての情報である。

artifact が大きいため 3 cycles が「明らかに不十分」なら、artifact が大きすぎる。Step 2 へ戻り分解する。上限を引き上げない。

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「自信があるので doubt step は省く」 | novel problems では自信と正しさの相関は弱い。確信の瞬間こそ blind spots が隠れる。 |
| 「reviewer 起動は高い」 | production の wrong commit を debug するほうが高い。この check は有界だが、bug は有界ではない。 |
| 「reviewer は nitpick するだけ」 | scope しなければそうなる。prompt を「contract 下で失敗させる issue」に制限する。 |
| 「最後に `/review` で doubt する」 | `/review` は最終 gate である。doubt-driven は course-correction が安いうちに wrong direction を捕まえる。PR 時点では遅すぎる。 |
| 「すべてを疑えば ship できない」 | このスキルは every keystroke ではなく non-trivial decisions に適用する。「使わない場面」を読み直す。 |
| 「2 つの意見は常に 1 つより良い」 | 2 つ目が context 不足で noise を生むなら違う。委ねず reconcile する。 |
| 「reviewer が反対したから自分が間違っていた」 | reviewer にはあなたの context がない。不一致は情報であり verdict ではない。artifact を読み直し、分類して判断する。 |
| 「cross-model は常に良い」 | single model が共有する blind spots を捕まえるが、cost と tool fragility も増やす。interactive doubt cycle では毎回提示し、ユーザーが判断する。 |
| 「ユーザーが一度 yes と言ったので CLI を続けて呼べる」 | 各 invocation は個別の authorization である。artifact、prompt、flags は呼び出しごとに変わる。毎回 exact command を再確認する。 |

## 危険信号

- 1 行 rename または formatting change に fresh-context reviewer を起動する
- artifact text を読み直さず reviewer output を authoritative に扱う
- ユーザーへ escalate せず >3 cycles loop する
- reviewer へ「これは良いですか」と尋ねる。正しくは「問題を見つけて」
- high-stakes decision で時間圧を理由に doubt を省く
- 未変更 artifact に fresh-context を再 spawn する（同じ findings が返るだけで、足踏みである）
- **Doubt theater（確認可能な signal）**: reviewer が substantive findings を出した 2 cycles 以上で、actionable と分類した finding がゼロ。疑っているのではなく validation している。停止して escalate する。
- commit 後だけ疑う。それは `/review` であり doubt-driven development ではない
- tool の存在、設定、syntax をユーザーへ確認せず external CLI invocation を hardcode する
- **interactive doubt cycle で cross-model を黙って skip する。** 推奨しない場合でも offer は可視でなければならない
- external CLI error または missing 時に黙って fallback する。失敗を表面化し、ユーザーに redirect させる
- reviewer input から contract を削る
- CLAIM を reviewer へ渡す（agreement へ bias する）

## 他スキルとの関係

- **`code-review-and-quality` / `/review`**: 補完関係。`/review` は post-hoc PR verdict、doubt-driven は in-flight per-decision。両方使う。
- **`source-driven-development`**: SDD は official docs で *framework facts* を検証する。doubt-driven は *artifact についての推論* を検証する。SDD は API が存在するかを確認し、doubt-driven は contract 下で正しく使ったかを確認する。
- **`test-driven-development`**: TDD の RED step は具体化された doubt である。失敗するテストは反証の試みである。TDD が適用される場合、その失敗テストは behavioral claims に対する doubt step である。
- **`debugging-and-error-recovery`**: reviewer が real failure mode を表面化したら、debugging skill に入って localize し fix する。
- **Repo orchestration rules**（`references/orchestration-patterns.md`）: このスキルは main session から orchestrate する。persona が別 persona を呼ぶのは anti-pattern B である。上の Loading Constraints を参照。

## 検証

doubt-driven development 適用後に確認する:

- [ ] 自明でない判断（上の定義による）は、立つ前にすべて CLAIM として明示的に名付けた
- [ ] 自明でない artifact ごとに少なくとも 1 回 fresh-context review を行った（TDD の RED step が作った失敗テストは、Interaction with Other Skills に従い behavioral claims ではこれを満たす）
- [ ] reviewer は ARTIFACT + CONTRACT を受け取った。CLAIM も reasoning も受け取っていない
- [ ] reviewer prompt は validating（「良いか」）ではなく adversarial（「問題を見つける」）だった
- [ ] findings は artifact text に照らして分類された（rubber-stamp ではない）。優先順は contract misread / actionable / trade-off / noise
- [ ] stop condition（trivial findings、3 cycles、または user override）を満たした
- [ ] interactive mode では、artifact stakes に関係なく cross-model をユーザーへ **明示的に提示** し、その response を output で認めた
- [ ] non-interactive mode では cross-model を skip し、skip を announce した
- [ ] external CLI invocation の前に、PATH check、working-binary test、ユーザーとの syntax confirmation、明示的な実行 authorization を行った
