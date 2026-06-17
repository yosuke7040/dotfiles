# sdd-cache フック

[`source-driven-development`](../skills/source-driven-development/SKILL.md) 用の、セッションをまたぐ引用キャッシュ。スキルの「現在のドキュメントで検証する」という保証を弱めずに、冗長な `WebFetch` 呼び出しを省く。

## なぜ必要か

`source-driven-development` は、フレームワーク固有の判断ごとに公式ドキュメントを取得する。同じプロジェクトをセッションをまたいで扱うと、同じページを何度も取得することになる。内容をローカルメモリとしてキャッシュすると、ドキュメントは変わり得るため、スキルの考え方と矛盾する。古いキャッシュが変更を隠してしまうからである。

このフックは取得した内容をディスクへキャッシュするが、再利用のたびに HTTP `If-None-Match` / `If-Modified-Since` によって **オリジンサーバーで再検証する**。サーバーが `304 Not Modified` を返した場合だけ、キャッシュから内容を返す。これはメモリ読み取りではなく、新鮮性の検証である。

## セットアップ

1. `.claude/settings.json`（個人用なら `.claude/settings.local.json`）へフックを追加する:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "WebFetch",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/sdd-cache-pre.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "WebFetch",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/sdd-cache-post.sh",
            "async": true,
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

   `${CLAUDE_PROJECT_DIR}` は、Claude Code を起動したディレクトリへ解決される。上の断片は、フックが同じプロジェクト内にある場合に動作する。`agent-skills` を別の場所へインストールした場合（例: `~/agent-skills` 配下の共有プラグイン）、`${CLAUDE_PROJECT_DIR}/hooks/...` を各スクリプトの絶対パスへ置き換える。

2. `.claude/sdd-cache/` が `.gitignore` に入っていることを確認する（このリポジトリではすでに含まれている）。

3. `/source-driven-development`（またはスキル）を通常どおり使う。スキルやエージェントのワークフローを変更する必要はない。キャッシュは透過的に働く。

## メンタルモデル

URL をキーにした HTTP リソースキャッシュである。新鮮性は `ETag` / `Last-Modified` を通じてオリジンへ委譲する。TTL はなく、プロンプトはキーに含めない。

保存される本文は生の HTML ではない。`WebFetch` は呼び出し元のプロンプトを使って各レスポンスをモデルで後処理するため、キャッシュされるのは、あるエージェントによるそのページの読み取りである。セッションをまたいで読み取りを再利用できるよう、キーは URL だけに保つ。元のプロンプトはメタデータとして保持され、ヒット時メッセージで表面化するため、次のエージェントは過去の読み取りが合うかを判断できる。

## 仕組み

URL ごとに 1 つのキャッシュエントリを `.claude/sdd-cache/<sha>.json` として保存する:

| イベント | 動作 |
|----------|------|
| `PreToolUse WebFetch` | エントリが存在する場合、`If-None-Match` / `If-Modified-Since` 付きで `HEAD` リクエストを送る。`304` の場合は fetch をブロックし、元のプロンプトをメタデータとして示しながら、stderr 経由でキャッシュ内容をエージェントへ返す。それ以外では fetch を許可する。 |
| `PostToolUse WebFetch` | レスポンスを取得し、`HEAD` リクエストで現在の `ETag` / `Last-Modified` を記録し、`{url, prompt, etag, last_modified, content, fetched_at}` を保存する。 |

**新鮮性ルール:**

- エントリは、オリジンが `304 Not Modified` を確認した場合だけ返す。
- `ETag` または `Last-Modified` ヘッダーのないエントリはキャッシュしない。バリデータがなければ、後で新鮮性を検証できず、キャッシュはメモリを信じることになる。
- キャッシュキーは `sha256(url)`。同じ URL を別のプロンプトで尋ねても同じエントリにヒットする。キャッシュ本文は最初の fetch で使われたプロンプトを反映し、そのプロンプトはヒット時に表示されるため、エージェントは再利用するか手動で再取得するかを判断できる。

**エージェントから見えるもの:**

- キャッシュヒット: `WebFetch` は終了コード 2 でブロックされる。Claude Code はフックの stderr ペイロードをツールエラーとしてエージェントへ返す。これはキャッシュヒットを示す意図されたシグナルであり、失敗ではない。ペイロードには `[sdd-cache] <url> のキャッシュヒット` という接頭辞が付き、キャッシュ本文を `----- キャッシュ済みコンテンツ開始 -----` / `----- キャッシュ済みコンテンツ終了 -----` マーカーで囲む。エージェントは `WebFetch` が今返した内容として使える。
- キャッシュミスまたは stale: `WebFetch` は通常どおり実行され、結果は次回のために保存される。

スキル自体は変わらない。`DETECT → FETCH → IMPLEMENT → CITE` に従い続ける。このフックは、`FETCH` 実行時の内部動作だけを変える。

## ローカルテスト

### 1. スクリプトを直接 smoke test する

```bash
# PostToolUse ペイロードをシミュレートする: ページをキャッシュ
echo '{
  "tool_input": {
    "url": "https://react.dev/reference/react/useActionState",
    "prompt": "extract the signature"
  },
  "tool_response": "useActionState(action, initialState) returns [state, formAction, isPending]"
}' | bash hooks/sdd-cache-post.sh

# 保存されたエントリを確認
ls .claude/sdd-cache/
cat .claude/sdd-cache/*.json | jq .

# 同じ URL + prompt に対する次の PreToolUse をシミュレート
echo '{
  "tool_input": {
    "url": "https://react.dev/reference/react/useActionState",
    "prompt": "extract the signature"
  }
}' | bash hooks/sdd-cache-pre.sh
echo "exit=$?"
```

期待結果:

- 最初のコマンドは `.claude/sdd-cache/` 配下に 1 ファイルを作る（サーバーが `ETag` または `Last-Modified` を返した場合のみ）。
- 2 番目のコマンドは、オリジンが `304` を返した場合は stderr にキャッシュ内容を出して `2` で終了し、それ以外では何も出さず `0` で終了する。

### 2. 実セッションでのエンドツーエンド

1. 上に示したとおり `.claude/settings.local.json` へフックを登録する。
2. このリポジトリで Claude Code セッションを開始する。
3. エージェントにドキュメントページを取得させる（例: 「`https://react.dev/reference/react/useActionState` を取得して要約して」）。
4. `.claude/sdd-cache/` 配下にファイルが現れることを確認する。
5. 同じプロンプトで同じページをもう一度取得するようエージェントに依頼する。
6. 2 回目の `WebFetch` がブロックされ、キャッシュ内容が返ることを確認する（セッション transcript では `[sdd-cache]` 接頭辞付きのツールエラーとして見える）。

### 3. 新鮮性の検証

ドキュメント変更時にキャッシュが無効化されることを確認するには、強制的に `ETag` 不一致を作る。キャッシュに複数ファイルがあると `*.json` は危険なので、特定のエントリを 1 つ選ぶ:

```bash
# 壊したいエントリを選ぶ（実際のファイル名に差し替える）
ENTRY=.claude/sdd-cache/e49c9f378670cfbb1d7d871b6dee16d9.json

# オリジンが認識しない ETag に書き換える
jq '.etag = "W/\"stale-etag-forced\""' "$ENTRY" > "$ENTRY.tmp" && mv "$ENTRY.tmp" "$ENTRY"

# 次の PreToolUse はミスになるはず（サーバーは 304 ではなく 200 を返す）
echo '{"tool_input":{"url":"...", "prompt":"..."}}' | bash hooks/sdd-cache-pre.sh
echo "exit=$?"   # 0 を期待（fetch が許可される）
```

### 4. デバッグ

デバッグモードが有効な場合、両フックはタイムスタンプ付きイベントを `.claude/sdd-cache/.debug.log` へ書く。次のいずれかで有効化する:

```bash
# オプション A: 環境変数（セッション単位）
SDD_CACHE_DEBUG=1 claude

# オプション B: sentinel ファイル（永続）
mkdir -p .claude/sdd-cache && touch .claude/sdd-cache/.debug
# 無効化: rm .claude/sdd-cache/.debug
```

ログには URL、検出した `tool_response` 形状、HEAD ステータス、各呼び出しがヒットまたはミスになった理由が記録される。キャッシュミスが予想外に見える場合に有用である。典型的には、オリジンがバリデータを出さなくなっている。

## 既知の制限

- **本文はプロンプトに依存する。** ヒット時は、以前のエージェントによるページの読み取りを返し、元プロンプトも表面化するため、現在のエージェントは適用できるかを判断できる。適用できない場合は `.claude/sdd-cache/` 配下のファイルを削除して再取得を強制する。
- **キャッシュ書き込みごとに追加の HEAD が必要である。** Claude Code は `WebFetch` が受け取ったレスポンスヘッダーを公開しないため、post フックは `ETag` / `Last-Modified` を取得するためにオリジンへ再問い合わせする。ミスごとに 1 往復増えるが、コア変更なしの純粋なフックとして保つための代償である。
- **`ETag` または `Last-Modified` のないサーバーはキャッシュしない。** ほとんどの公式ドキュメントサイト（react.dev、docs.djangoproject.com、developer.mozilla.org）はバリデータを出す。出さないサイトは毎回再取得される。
- **不正なサーバーが誤った `304` を返す可能性はある。** それは診断すべきサーバーバグであり、キャッシュ不変条件として防ぐ対象ではない。TTL でごまかさない。古いエントリを見つけたら削除する。
- **キャッシュはローカルかつプロジェクト単位である。** チーム全体の共有キャッシュはない。それを追加するには署名付き content-addressable storage 層が必要であり、この範囲外である。

## 要件

- `jq`
- `curl`
- `shasum` または `sha256sum`（自動検出）
- Bash 3.2+
