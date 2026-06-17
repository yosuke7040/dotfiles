# セキュリティチェックリスト

web application security のクイックリファレンス。`security-and-hardening` skill と併用する。

## 目次

- [Threat Modeling（ここから始める）](#threat-modelingここから始める)
- [Pre-Commit Checks](#pre-commit-checks)
- [Authentication](#authentication)
- [Authorization](#authorization)
- [Input Validation](#input-validation)
- [Security Headers](#security-headers)
- [CORS Configuration](#cors-configuration)
- [Data Protection](#data-protection)
- [Dependency Security](#dependency-security)
- [AI / LLM Security](#ai--llm-security)
- [Error Handling](#error-handling)
- [OWASP Top 10 Quick Reference](#owasp-top-10-quick-reference)
- [OWASP Top 10 for LLMs Quick Reference](#owasp-top-10-for-llms-quick-reference)

## 脅威モデリング（ここから始める）

controls に飛びつく前に、attacker の視点で 5 分考える。

- [ ] trust boundaries を map した（requests、uploads、webhooks、third-party APIs、LLM output）
- [ ] assets を名付けた（credentials、PII、payment data、admin actions、money movement）
- [ ] boundary ごとに STRIDE を実行した（Spoofing、Tampering、Repudiation、Info disclosure、DoS、Elevation）
- [ ] use cases の横に abuse cases を書いた（「どう悪用できるか？」）

## commit 前チェック

- [ ] code に secrets がない（`git diff --cached | grep -i "password\|secret\|api_key\|token"`）
- [ ] `.gitignore` が `.env`、`.env.local`、`*.pem`、`*.key` を覆っている
- [ ] `.env.example` が placeholder values を使っている（real secrets ではない）

## 認証

- [ ] passwords を bcrypt（12 rounds 以上）、scrypt、または argon2 で hash している
- [ ] session cookies: `httpOnly`、`secure`、`sameSite: 'lax'`
- [ ] session expiration を設定している（reasonable max-age）
- [ ] login endpoint に rate limiting がある（15 分あたり 10 attempts 以下）
- [ ] password reset tokens: time-limited（1 時間以下）、single-use
- [ ] repeated failures 後の account lockout（任意、notification 付き）
- [ ] sensitive operations 向けに MFA support（任意だが推奨）

## 認可

- [ ] every protected endpoint が authentication を確認する
- [ ] every resource access が ownership / role を確認する（IDOR を防ぐ）
- [ ] admin endpoints は admin role verification を要求する
- [ ] API keys は必要最小限の permissions に scoped されている
- [ ] JWT tokens を validation している（signature、expiration、issuer）

## 入力検証

- [ ] すべての user input を system boundaries で validation している（API routes、form handlers）
- [ ] validation は allowlists を使う（denylists ではない）
- [ ] string lengths を制約している（min / max）
- [ ] numeric ranges を validation している
- [ ] email、URL、date formats を適切な libraries で validation している
- [ ] file uploads: type restricted、size limited、content verified
- [ ] SQL queries を parameterized している（string concatenation なし）
- [ ] HTML output を encode している（framework auto-escaping を使う）
- [ ] redirect 前に URLs を validation している（open redirect を防ぐ）
- [ ] server-side URL fetches は allowlisted で、private / reserved IPs を block している（SSRF を防ぐ）

## セキュリティヘッダー

```
Content-Security-Policy: default-src 'self'; script-src 'self'
Strict-Transport-Security: max-age=31536000; includeSubDomains
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 0  (disabled, rely on CSP)
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
```

## CORS 設定

```typescript
// restrictive（推奨）
cors({
  origin: ['https://yourdomain.com', 'https://app.yourdomain.com'],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'Authorization'],
})

// production では絶対に使わない:
cors({ origin: '*' })  // any origin を許可する
```

## データ保護

- [ ] sensitive fields を API responses から除外している（`passwordHash`、`resetToken` など）
- [ ] sensitive data を log していない（passwords、tokens、full CC numbers）
- [ ] PII を at rest で encrypted している（regulation が required なら）
- [ ] すべての external communication で HTTPS
- [ ] database backups を encrypted している

## 依存関係のセキュリティ

```bash
# dependencies を audit する
npm audit

# 可能な範囲で自動修正する
npm audit fix

# critical vulnerabilities を確認する
npm audit --audit-level=critical

# dependencies を更新する
npx npm-check-updates
```

**Supply-chain hygiene**（`npm audit` は malicious packages を検出できない）:

- [ ] lockfile を commit し、CI は `npm install` ではなく `npm ci` で install する
- [ ] new dependencies を review する（maintenance、downloads、`postinstall` scripts）
- [ ] typosquats がない（`cross-env` vs `crossenv`、`react-dom` vs `reactdom`）

## AI / LLM セキュリティ

LLM を呼ぶ feature（chatbots、summarizers、agents、RAG）では:

- [ ] model output を untrusted として扱う。`eval` / SQL / shell / `innerHTML` / file paths に直接入れない
- [ ] prompt injection を前提にし、permissions は system prompt ではなく code で enforce する
- [ ] secrets、cross-tenant data、full system prompts を context window に入れない
- [ ] tool / agent permissions を scoped し、destructive または irreversible actions は confirmation を要求する
- [ ] token、rate、recursion / loop limits を設定する（consumption を bound する）

## エラー処理

```typescript
// production: generic error。internals を出さない
res.status(500).json({
  error: { code: 'INTERNAL_ERROR', message: '問題が発生しました' }
});

// production では絶対にしない:
res.status(500).json({
  error: err.message,
  stack: err.stack,         // internals を露出する
  query: err.sql,           // database details を露出する
});
```

## OWASP Top 10 クイックリファレンス

| # | 脆弱性 | 予防 |
|---|---|---|
| 1 | Broken Access Control | every endpoint の auth checks、ownership verification |
| 2 | Cryptographic Failures | HTTPS、strong hashing、code に secrets を置かない |
| 3 | Injection | parameterized queries、input validation |
| 4 | Insecure Design | threat modeling、spec-driven development |
| 5 | Security Misconfiguration | security headers、minimal permissions、deps audit |
| 6 | Vulnerable Components | `npm audit`、deps 更新、minimal deps |
| 7 | Auth Failures | strong passwords、rate limiting、session management |
| 8 | Data Integrity Failures | updates / dependencies の verify、signed artifacts |
| 9 | Logging Failures | security events を log し、secrets を log しない |
| 10 | SSRF | URLs の validation / allowlist、outbound requests 制限 |

## LLM 向け OWASP Top 10 クイックリファレンス

LLM features を持つ apps 向け。[OWASP GenAI Security Project](https://genai.owasp.org/llm-top-10/) を参照。

| ID | リスク | 予防 |
|---|---|---|
| LLM01 | Prompt Injection | system prompt を boundary として信頼しない。permissions は code で enforce する |
| LLM02 | Sensitive Information Disclosure | secrets / PII を prompts から外し、outputs を filter する |
| LLM03 | Supply Chain | models、datasets、plugins を dependency と同じように vet する |
| LLM04 | Data and Model Poisoning | trusted model sources を使い、integrity を verify する。fine-tuning と RAG data を vet する |
| LLM05 | Improper Output Handling | model output を untrusted として扱い、validate / parameterize / encode する |
| LLM06 | Excessive Agency | tool permissions を scoped し、destructive actions は confirm する |
| LLM07 | System Prompt Leakage | system prompt は leak し得る前提にし、secrets を入れない |
| LLM08 | Vector and Embedding Weaknesses | RAG embeddings を tenant ごとに partition し、indexing 前に documents を validate する |
| LLM09 | Misinformation | citations で answers を ground し、critical claims を validate し、人間を loop に置く |
| LLM10 | Unbounded Consumption | tokens、request rate、loop / recursion depth を cap する |
