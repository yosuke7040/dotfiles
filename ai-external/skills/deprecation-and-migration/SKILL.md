---
name: deprecation-and-migration
description: 廃止と移行を管理する。古い systems、APIs、features を削除する場合に使う。users を一つの implementation から別の implementation へ移行する場合に使う。既存 code を維持するか廃止するか判断する場合に使う。
---

# 非推奨化と移行

## 概要

コードは asset ではなく liability である。すべての行には継続的な maintenance cost がある。bugs を直し、dependencies を更新し、security patches を適用し、新しい engineers を onboard する必要がある。deprecation は、もう維持に見合わない code を削除する規律であり、migration は users を古いものから新しいものへ安全に移すプロセスである。

多くの engineering organizations は作ることが得意だが、削除は得意ではない。このスキルはその gap を扱う。

## 使う場面

- 古い system、API、library を新しいものへ置き換える
- もう不要な feature を sunset する
- duplicate implementations を統合する
- 誰も ownership を持たないが全員が依存する dead code を削除する
- 新しい system の lifecycle を計画する（deprecation planning は design time から始まる）
- legacy system を維持するか migration へ投資するか判断する

## 中核原則

### code は負債である

すべての code には ongoing cost がある。tests、documentation、security patches、dependency updates、近くで作業する人の mental overhead が必要である。code の価値は code そのものではなく、提供する functionality である。同じ functionality を少ない code、少ない complexity、またはより良い abstractions で提供できるなら、古い code は消すべきである。

### Hyrum's Law により削除は難しい

十分な users がいると、観測可能な behavior はすべて依存される。bugs、timing quirks、undocumented side effects も含む。だから deprecation には announcement だけでなく active migration が必要である。replacement が再現しない behavior に依存している users は「ただ切り替える」ことができない。

### deprecation planning は design time に始まる

新しいものを作るとき、「3 年後にこれをどう削除するか」と問う。clean interfaces、feature flags、minimal surface area で設計された systems は、implementation details をあちこちへ漏らす systems より deprecate しやすい。

## deprecation 判断

何かを deprecate する前に答える:

```
1. この system はまだ unique value を提供しているか
   → yes なら maintain。no なら続行。

2. どれだけの users/consumers が依存しているか
   → migration scope を定量化する。

3. replacement は存在するか
   → no なら先に replacement を作る。alternative なしに deprecate しない。

4. 各 consumer の migration cost は何か
   → trivial に自動化できるなら行う。manual かつ high-effort なら maintenance cost と比較する。

5. deprecate しない ongoing maintenance cost は何か
   → security risk、engineer time、complexity の opportunity cost。
```

## compulsory vs advisory deprecation

| 種類 | 使う場面 | 仕組み |
|------|----------|--------|
| **Advisory** | migration は optional、old system は stable | warnings、documentation、nudges。users は自分の timeline で移行 |
| **Compulsory** | old system に security issues がある、progress を block する、maintenance cost が持続不能 | hard deadline。old system は date X に削除。migration tooling を提供 |

**既定は advisory。** maintenance cost または risk が forced migration を正当化する場合だけ compulsory を使う。compulsory deprecation には migration tooling、documentation、support が必要である。deadline を告知するだけでは足りない。

## migration process

### step 1: replacement を作る

動く alternative なしに deprecate しない。replacement は次を満たす:

- old system の critical use cases をすべて cover する
- documentation と migration guides がある
- production で証明済みである（「理論上よい」だけではない）

### step 2: announce and document

```markdown
## deprecation notice: OldService

**Status:** 2025-03-01 から Deprecated
**Replacement:** NewService（下の migration guide を参照）
**Removal date:** Advisory。hard deadline はまだなし
**Reason:** OldService は manual scaling が必要で observability がない。
            NewService は両方を自動で扱う。

### migration guide
1. `import { client } from 'old-service'` を `import { client } from 'new-service'` に置換
2. configuration を更新（下の examples を参照）
3. migration verification script を実行: `npx migrate-check`
```

### step 3: incremental に移行する

consumer を一度に全部ではなく 1 つずつ移行する。各 consumer について:

```
1. deprecated system との touchpoints をすべて特定
2. replacement を使うよう更新
3. behavior が一致することを検証（tests、integration checks）
4. old system への references を削除
5. regression がないことを確認
```

**Churn Rule:** deprecated される infrastructure を owning しているなら、users の migration に責任を持つ。あるいは migration 不要の backward-compatible updates を提供する。deprecation を告知して users に丸投げしない。

### step 4: old system を削除する

すべての consumers が migrated した後だけ削除する:

```
1. active usage が 0 であることを検証（metrics、logs、dependency analysis）
2. code を削除
3. 関連 tests、documentation、configuration を削除
4. deprecation notices を削除
5. code 削除は成果である
```

## migration patterns

### strangler pattern

old と new systems を並列に走らせる。traffic を old から new へ段階的に route する。old system の traffic が 0% になったら削除する。

```
Phase 1: New system 0%, old 100%
Phase 2: New system 10% (canary)
Phase 3: New system 50%
Phase 4: New system 100%, old idle
Phase 5: old system を削除
```

### adapter pattern

old interface から new implementation へ calls を変換する adapter を作る。consumers は backend migration 中も old interface を使い続けられる。

```typescript
class LegacyTaskService implements OldTaskAPI {
  constructor(private newService: NewTaskService) {}

  getTask(id: number): OldTask {
    const task = this.newService.findById(String(id));
    return this.toOldFormat(task);
  }
}
```

### feature flag migration

feature flags を使い、consumer を 1 つずつ old から new system へ切り替える:

```typescript
function getTaskService(userId: string): TaskService {
  if (featureFlags.isEnabled('new-task-service', { userId })) {
    return new NewTaskService();
  }
  return new LegacyTaskService();
}
```

## zombie code

zombie code は、誰も owning していないが全員が依存する code である。active に maintained されず、clear owner がなく、security vulnerabilities と compatibility issues を蓄積する。兆候:

- 6 か月以上 commits がないが active consumers がいる
- assigned maintainer または team がない
- 誰も直さない failing tests
- 誰も更新しない known vulnerabilities 付き dependencies
- もう存在しない systems を参照する documentation

**対応:** owner を割り当てて正しく maintain するか、具体的 migration plan 付きで deprecate する。zombie code を limbo に置いてはならない。投資するか削除するかである。

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「まだ動いているのになぜ削除するのか」 | 誰も maintain しない動作コードは security debt と complexity を蓄積する。maintenance cost は静かに増える。 |
| 「誰かが後で必要とするかも」 | 必要になれば再構築できる。念のため unused code を残す cost は、再構築より高いことが多い。 |
| 「migration が高すぎる」 | 2-3 年の ongoing maintenance cost と比べる。長期的には migration のほうが安いことが多い。 |
| 「新 system が終わったら deprecate する」 | deprecation planning は design time に始まる。new system 完了時には新しい priorities がある。今計画する。 |
| 「users は自分で migrate する」 | しない。tooling、documentation、incentives を提供するか、自分で migration する（Churn Rule）。 |
| 「両方の systems を無期限に維持できる」 | 同じことをする 2 systems は、maintenance、testing、documentation、onboarding cost を倍にする。 |

## 危険信号

- replacement がない deprecated systems
- migration tooling または documentation のない deprecation announcements
- 何年も progress なしで advisory のままの "soft" deprecation
- owner がなく active consumers がいる zombie code
- deprecated system へ new features を追加する（replacement に投資する）
- current usage を測らない deprecation
- active consumers が 0 であることを検証せず code を削除する

## 検証

deprecation 完了後に確認する:

- [ ] replacement は production-proven で、critical use cases をすべて cover している
- [ ] concrete steps と examples を持つ migration guide がある
- [ ] active consumers がすべて migrated している（metrics/logs で検証）
- [ ] old code、tests、documentation、configuration が完全に削除されている
- [ ] codebase に deprecated system への references が残っていない
- [ ] deprecation notices が削除されている（役目を終えた）
