---
name: security-and-hardening
description: 脆弱性に対してコードを強化する。user input、authentication、data storage、external integrations を扱う場合に使う。untrusted data を受け取る機能、user sessions を管理する機能、third-party services とやり取りする機能を作る場合に使う。
---

# セキュリティと強化

## 概要

Web アプリケーション向けの security-first development practices。すべての外部入力を敵対的に扱い、すべての secret を神聖なものとして扱い、すべての authorization check を必須として扱う。セキュリティはフェーズではない。user data、authentication、external systems に触れるすべてのコード行にかかる制約である。

## 使う場面

- user input を受け取るものを作る
- authentication または authorization を実装する
- sensitive data を保存または送信する
- external APIs または services と統合する
- file uploads、webhooks、callbacks を追加する
- payment または PII data を扱う

## プロセス: 脅威モデルを先に

脅威モデルなしで後付けされた controls は推測である。強化前に 5 分だけ攻撃者として考える:

1. **trust boundaries を対応づける。** untrusted data はどこから system へ入るか。HTTP requests、form fields、file uploads、webhooks、third-party APIs、message queues、そして **LLM output**。すべての boundary は attack surface である。
2. **assets を名付ける。** 何が盗まれたり壊されたりすると困るか。credentials、PII、payment data、admin actions、money movement。
3. **各 boundary に STRIDE をかける**。儀式ではなく、素早い lens として使う。

| Threat | 問い | 典型的な緩和策 |
|--------|------|----------------|
| **S**poofing | 誰かが user/service になりすませるか | Authentication、signature verification |
| **T**ampering | data が transit または rest で改ざんされるか | Integrity checks、parameterized queries、HTTPS |
| **R**epudiation | action を後で否認できるか | security events の audit logging |
| **I**nformation disclosure | data が漏れるか | Encryption、field allowlists、generic errors |
| **D**enial of service | 圧倒されるか | Rate limiting、input size caps、timeouts |
| **E**levation of privilege | user が持つべきでない rights を得られるか | Authorization checks、least privilege |

4. **use cases の横に abuse cases を書く。** 各 feature について「これをどう悪用するか」と問う。それを最初の test にする。

feature の trust boundaries を名付けられないなら、まだ secure にする準備はできていない。これは OWASP **A04: Insecure Design** である。多くの侵害は code ではなく design から始まる。

## 3 層 boundary system

### 常に行う（例外なし）

- **すべての external input を system boundary で検証する**（API routes、form handlers）
- **すべての database queries を parameterize する**。user input を SQL へ連結しない
- **output を encode する** ことで XSS を防ぐ（framework auto-escaping を使い、bypass しない）
- **すべての external communication に HTTPS を使う**
- **passwords は bcrypt/scrypt/argon2 で hash する**（plaintext 保存しない）
- **security headers を設定する**（CSP、HSTS、X-Frame-Options、X-Content-Type-Options）
- **sessions には httpOnly、secure、sameSite cookies を使う**
- **release 前に `npm audit`**（または equivalent）を実行する

### 先に確認する（人間の承認が必要）

- 新しい authentication flows の追加、または auth logic 変更
- 新しい category の sensitive data（PII、payment info）保存
- 新しい external service integrations
- CORS configuration 変更
- file upload handlers 追加
- rate limiting または throttling 変更
- elevated permissions または roles の付与

### 決して行わない

- **secrets を version control に commit しない**（API keys、passwords、tokens）
- **sensitive data を log しない**（passwords、tokens、full credit card numbers）
- **client-side validation を security boundary として信頼しない**
- **利便性のために security headers を無効化しない**
- **user-provided data とともに `eval()` または `innerHTML` を使わない**
- **sessions を client-accessible storage に保存しない**（auth tokens 用 localStorage など）
- **stack traces または internal error details を users へ露出しない**

## OWASP Top 10 防御パターン

### injection（SQL、NoSQL、OS command）

```typescript
// 悪い例: string concatenation による SQL injection
const query = `SELECT * FROM users WHERE id = '${userId}'`;

// 良い例: parameterized query
const user = await db.query('SELECT * FROM users WHERE id = $1', [userId]);

// 良い例: parameterized input を使う ORM
const user = await prisma.user.findUnique({ where: { id: userId } });
```

### broken authentication

```typescript
import { hash, compare } from 'bcrypt';

const SALT_ROUNDS = 12;
const hashedPassword = await hash(plaintext, SALT_ROUNDS);
const isValid = await compare(plaintext, hashedPassword);

app.use(session({
  secret: process.env.SESSION_SECRET,  // code ではなく environment から
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,     // JavaScript から access 不可
    secure: true,       // HTTPS only
    sameSite: 'lax',    // CSRF protection
    maxAge: 24 * 60 * 60 * 1000,
  },
}));
```

### cross-site scripting（XSS）

```typescript
// 悪い例: user input を HTML として render
element.innerHTML = userInput;

// 良い例: framework auto-escaping を使う（React は既定で行う）
return <div>{userInput}</div>;

// どうしても HTML render が必要なら先に sanitize する
import DOMPurify from 'dompurify';
const clean = DOMPurify.sanitize(userInput);
```

### broken access control

```typescript
// authentication だけでなく authorization も必ず確認する
app.patch('/api/tasks/:id', authenticate, async (req, res) => {
  const task = await taskService.findById(req.params.id);

  if (task.ownerId !== req.user.id) {
    return res.status(403).json({
      error: { code: 'FORBIDDEN', message: 'この task を変更する権限がありません' }
    });
  }

  const updated = await taskService.update(req.params.id, req.body);
  return res.json(updated);
});
```

### security misconfiguration

```typescript
import helmet from 'helmet';
app.use(helmet());

app.use(helmet.contentSecurityPolicy({
  directives: {
    defaultSrc: ["'self'"],
    scriptSrc: ["'self'"],
    styleSrc: ["'self'", "'unsafe-inline'"],  // 可能ならさらに絞る
    imgSrc: ["'self'", 'data:', 'https:'],
    connectSrc: ["'self'"],
  },
}));

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || 'http://localhost:3000',
  credentials: true,
}));
```

### sensitive data exposure

```typescript
// API responses で sensitive fields を返さない
function sanitizeUser(user: UserRecord): PublicUser {
  const { passwordHash, resetToken, ...publicFields } = user;
  return publicFields;
}

const API_KEY = process.env.STRIPE_API_KEY;
if (!API_KEY) throw new Error('STRIPE_API_KEY not configured');
```

### server-side request forgery（SSRF）

server が user 影響下の URL を fetch するとき（webhooks、"import from URL"、image proxies、link previews）、攻撃者は internal services（cloud metadata、`localhost`、private IPs）を狙える。

```typescript
// 悪い例: user が渡したものをそのまま fetch
await fetch(req.body.webhookUrl);

// 良い例: scheme + host を allowlist し、resolved IP が private なら拒否し、redirects を禁止
import { lookup } from 'node:dns/promises';
import ipaddr from 'ipaddr.js';

const ALLOWED_HOSTS = new Set(['hooks.example.com']);

async function assertSafeUrl(raw: string): Promise<URL> {
  const url = new URL(raw);
  if (url.protocol !== 'https:') throw new Error('https only');
  if (!ALLOWED_HOSTS.has(url.hostname)) throw new Error('host not allowed');
  const addrs = await lookup(url.hostname, { all: true });
  if (addrs.some((a) => ipaddr.parse(a.address).range() !== 'unicast')) {
    throw new Error('private/reserved IP');
  }
  return url;
}

await fetch(await assertSafeUrl(req.body.webhookUrl), { redirect: 'error' });
```

`range() !== 'unicast'` は IPv4/IPv6 の loopback、link-local `169.254.169.254`（cloud metadata、最大の SSRF target）、private、unique-local ranges を含む。

**注意: これでも TOCTOU gap は残る。** `fetch` は check 後に DNS を再解決するため、short-TTL record を使う攻撃者が validation と connection の間に internal IP へ rebind できる。高リスク surface では、1 回だけ resolve して pinned IP へ接続するか、filtering agent（`request-filtering-agent` / `ssrf-req-filter`）を前段に置く。

## 入力検証パターン

### 境界で schema validation

```typescript
import { z } from 'zod';

const CreateTaskSchema = z.object({
  title: z.string().min(1).max(200).trim(),
  description: z.string().max(2000).optional(),
  priority: z.enum(['low', 'medium', 'high']).default('medium'),
  dueDate: z.string().datetime().optional(),
});

app.post('/api/tasks', async (req, res) => {
  const result = CreateTaskSchema.safeParse(req.body);
  if (!result.success) {
    return res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Invalid input',
        details: result.error.flatten(),
      },
    });
  }
  const task = await taskService.create(result.data);
  return res.status(201).json(task);
});
```

### file upload safety

```typescript
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const MAX_SIZE = 5 * 1024 * 1024; // 5MB

function validateUpload(file: UploadedFile) {
  if (!ALLOWED_TYPES.includes(file.mimetype)) {
    throw new ValidationError('File type not allowed');
  }
  if (file.size > MAX_SIZE) {
    throw new ValidationError('File too large (max 5MB)');
  }
  // file extension は信頼しない。重要なら magic bytes を確認する
}
```

## npm audit 結果の triage

すべての audit finding が即時対応を要するわけではない。次の decision tree を使う:

```
npm audit reports a vulnerability
├── Severity: critical or high
│   ├── vulnerable code は app で reachable か
│   │   ├── YES --> 即時修正（update、patch、または dependency 置換）
│   │   └── NO（dev-only dep、unused code path） --> 近く修正。ただし blocker ではない
│   └── fix はあるか
│       ├── YES --> patched version へ update
│       └── NO --> workaround を確認、dependency 置換を検討、または review date 付きで allowlist
├── Severity: moderate
│   ├── production で reachable? --> 次 release cycle で修正
│   └── dev-only? --> 都合のよい時に修正し backlog へ記録
└── Severity: low
    └── 通常の dependency updates で追跡、修正
```

defer する場合は理由を書き、review date を設定する。

### supply-chain hygiene

`npm audit` は既知 CVE を捕まえるが、悪意ある package や typosquat は捕まえない。

- **lockfile を commit** し、CI では `npm install` ではなく `npm ci` で install する。reproducible builds にし、silent version drift を防ぐ。
- **新しい dependencies は追加前に review** する。maintenance、download counts、本当に必要かを確認する。すべての dependency は attack surface である（OWASP **A06: Vulnerable Components**、**LLM03: Supply Chain**）。
- **見慣れない package の `postinstall` scripts に注意する**。install 時に任意コードを実行する。
- **typosquats に注意する**。`cross-env` と `crossenv`、`react-dom` と `reactdom` など。

## rate limiting

```typescript
import rateLimit from 'express-rate-limit';

app.use('/api/', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 100,
  standardHeaders: true,
  legacyHeaders: false,
}));

app.use('/api/auth/', rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
}));
```

## secrets management

```
.env files:
  ├── .env.example  → commit する（placeholder values の template）
  ├── .env          → commit しない（real secrets）
  └── .env.local    → commit しない（local overrides）

.gitignore に含める:
  .env
  .env.local
  .env.*.local
  *.pem
  *.key
```

**commit 前に必ず確認する:**
```bash
git diff --cached | grep -i "password\|secret\|api_key\|token"
```

**secret を一度でも commit したら rotate する。** 行削除や history rewrite だけでは足りない。remote に届いた瞬間に compromised とみなす。先に key を revoke/reissue し、その後 history から purge する。

## AI / LLM 機能の保護

アプリが LLM を呼ぶ場合（chatbots、summarizers、agents、RAG）、新しい attack surface を持つ。[OWASP Top 10 for LLM Applications (2025)](https://genai.owasp.org/llm-top-10/) に対応づける:

- **model output はすべて untrusted input として扱う（LLM05: Improper Output Handling）。** LLM output を `eval`、SQL、shell、`innerHTML`、file path へ直接渡さない。raw user input と同じように validate し encode する。
- **prompts は hijack され得ると仮定する（LLM01: Prompt Injection）。** context window 内の untrusted text、user message、fetched web page、PDF は instructions を持ち得る。system prompt は security boundary ではない。permissions は prompt ではなく code で強制する。
- **secrets と他ユーザーの data を prompts へ入れない（LLM02 / LLM07）。** context 内のものは echo され得る。API keys、cross-tenant data、full system prompt を model が繰り返せる場所へ置かない。
- **tool と agent permissions を制限する（LLM06: Excessive Agency）。** tools は最小権限にし、destructive または irreversible actions には confirmation を要求し、すべての tool arguments を validate する。
- **consumption を制限する（LLM10: Unbounded Consumption）。** tokens、request rate、loop/recursion depth に上限を置く。
- **retrieval data を分離する（LLM08: Vector and Embedding Weaknesses）。** RAG では vector store を trust boundary として扱う。tenant ごとに embeddings を分割し、poisoned content が answers を誘導しないよう indexing 前に documents を validate する。

```typescript
// 悪い例: model output を command または markup として信頼
const sql = await llm.generate(`Write SQL for: ${userQuestion}`);
await db.query(sql);
container.innerHTML = await llm.reply(userMessage);

// 良い例: model output は data。defensively parse し、validate し、encode する
let intent;
try {
  intent = CommandSchema.parse(JSON.parse(await llm.replyJson(userMessage)));
} catch {
  throw new ValidationError('unexpected model output');
}
await runAllowlistedAction(intent.action, intent.params);
container.textContent = await llm.reply(userMessage);
```

## セキュリティレビューチェックリスト

```markdown
### authentication
- [ ] Passwords は bcrypt/scrypt/argon2 で hash（salt rounds ≥ 12）
- [ ] Session tokens は httpOnly、secure、sameSite
- [ ] Login に rate limiting がある
- [ ] Password reset tokens が expire する

### authorization
- [ ] すべての endpoint が user permissions を確認する
- [ ] users は自分の resources だけへ access できる
- [ ] admin actions は admin role verification を要求する

### input
- [ ] すべての user input が boundary で validation される
- [ ] SQL queries が parameterized
- [ ] HTML output が encoded/escaped
- [ ] Server-side URL fetches が allowlisted（internal services への SSRF なし）

### data
- [ ] code または version control に secrets がない
- [ ] API responses から sensitive fields が除外されている
- [ ] PII が必要に応じて at rest で encrypted

### infrastructure
- [ ] Security headers configured（CSP、HSTS など）
- [ ] CORS が known origins に制限されている
- [ ] Dependencies audited for vulnerabilities
- [ ] Error messages が internals を露出しない

### supply chain
- [ ] Lockfile committed。CI は `npm ci` で install
- [ ] New dependencies reviewed（maintenance、downloads、postinstall scripts）

### AI / LLM（使用する場合）
- [ ] Model output を untrusted として扱う（eval/SQL/innerHTML/shell なし）
- [ ] Secrets と他ユーザーの data を prompts に入れない
- [ ] Tool/agent permissions が scoped。destructive actions は confirmation 必須
```

## 関連資料

詳細な security checklists と pre-commit verification steps は `references/security-checklist.md` を参照する。

## よくある正当化

| 正当化 | 現実 |
|--------|------|
| 「internal tool だから security は重要でない」 | internal tools も侵害される。攻撃者は最も弱い link を狙う。 |
| 「security は後で追加する」 | 後付け security は最初から組み込むより 10 倍難しい。今入れる。 |
| 「誰もこれを exploit しない」 | automated scanners が見つける。security by obscurity は security ではない。 |
| 「framework が security を扱う」 | framework は tools を提供するが、保証はしない。正しく使う必要がある。 |
| 「prototype だから」 | prototypes は production になる。初日から security habits を作る。 |
| 「ここで threat modeling はやりすぎ」 | 5 分の「どう攻撃するか」は、後からどの control でも直せない design flaws を防ぐ。 |
| 「LLM output はただの text」 | その text は SQL statement、script tag、shell command になり得る。untrusted input として扱う。 |

## 危険信号

- user input が database queries、shell commands、HTML rendering へ直接渡る
- source code または commit history に secrets がある
- authentication または authorization checks のない API endpoints
- CORS configuration 欠落または wildcard (`*`) origins
- authentication endpoints に rate limiting がない
- stack traces または internal errors が users へ露出する
- known critical vulnerabilities を持つ dependencies
- server が user-supplied URLs を allowlist なしに fetch する（SSRF）
- LLM/model output が query、DOM、shell、`eval` へ渡る
- secrets、PII、または full system prompt が LLM context window に入る

## 検証

security-relevant code 実装後に確認する:

- [ ] `npm audit` に critical または high vulnerabilities がない
- [ ] source code または git history に secrets がない
- [ ] すべての user input が system boundaries で validated
- [ ] protected endpoint すべてで authentication と authorization が確認されている
- [ ] response に security headers がある（browser DevTools で確認）
- [ ] error responses が internal details を露出しない
- [ ] auth endpoints で rate limiting が有効
- [ ] server-side URL fetches が allowlist に対して validated（SSRF なし）
- [ ] AI features がある場合、LLM/model output が使用前に validated かつ encoded
