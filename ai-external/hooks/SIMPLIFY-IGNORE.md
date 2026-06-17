# simplify-ignore フック

`/code-simplify` 向けのブロック単位保護。絶対に単純化してほしくないコードに印を付けると、モデルからは見えなくなる。

## セットアップ

1. 保護したいブロックに注釈を付ける:

```js
/* simplify-ignore-start: perf-critical */
// 手動で展開した XOR。ループより 3 倍速い
result[0] = buf[0] ^ key[0];
result[1] = buf[1] ^ key[1];
result[2] = buf[2] ^ key[2];
result[3] = buf[3] ^ key[3];
/* simplify-ignore-end */
```

2. `.claude/settings.json` にフックを追加する:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read",
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh" }]
      }
    ],
    "Stop": [
      {
        "hooks": [{ "type": "command", "command": "bash ${CLAUDE_PROJECT_DIR}/hooks/simplify-ignore.sh" }]
      }
    ]
  }
}
```

3. `/code-simplify` を実行する。保護されたブロックは `/* BLOCK_de115a1d: perf-critical */` のようなプレースホルダーになる。モデルは、保護された実装を見ずに周辺コードについて推論する。

> **注意:** このフックは一時バックアップを `.claude/.simplify-ignore-cache/` に保存する。このパスが `.gitignore` に入っていることを確認する。

## 仕組み

1 つのスクリプトが 3 つのフックイベントを扱う:

| イベント | 動作 |
|----------|------|
| `PreToolUse Read` | ファイルをバックアップし、ブロックを `BLOCK_<hash>` プレースホルダーでインプレース置換する |
| `PostToolUse Edit\|Write` | プレースホルダーを実コードへ戻し、モデルの変更を保存し、再フィルタする |
| `Stop` | セッション終了時に、すべてのファイルをバックアップから復元する |

各ブロックは内容からハッシュ化される（`shasum` / `sha1sum` による 8 桁 hex）ため、モデルがプレースホルダーを複製または並べ替えても、往復変換は曖昧にならない。キャッシュはプロジェクト単位であり、セッション間の干渉を防ぐ。

## 注釈構文

```js
/* simplify-ignore-start */           // 基本。ブロックを隠す
/* simplify-ignore-start: reason */   // 理由付き。プレースホルダーに表示される
/* simplify-ignore-end */
```

任意のコメント形式（`//`、`/*`、`#`、`<!--`）が使える。1 ファイル内の複数ブロックと単一行ブロックに対応している。プレースホルダーは元のコメント構文を保つ（例: Python では `# BLOCK_xxx`、HTML では `<!-- BLOCK_xxx -->`）。

## クラッシュ復旧

Claude Code が Stop フックを起動せずにクラッシュした場合、ディスク上のファイルに `BLOCK_<hash>` プレースホルダーが残ることがある。手動で復元するには:

```bash
echo '{}' | bash hooks/simplify-ignore.sh
```

バックアップは、プロジェクトディレクトリ内の `.claude/.simplify-ignore-cache/` に保存される。

## 既知の制限

- **単一行ブロックは行全体を隠す。** `simplify-ignore-start` と `simplify-ignore-end` が他のコードと同じ行にある場合、注釈された部分だけでなく行全体がモデルから隠される。注釈には専用行を使う。
- **コメント終端の検出は `*/` と `-->` だけを扱う。** 標準的でないコメント終端を持つテンプレートエンジン（ERB の `%>`、Blade の `--}}`）では、プレースホルダーのバランスが崩れることがある。代わりに `#` または `//` 形式のコメントを使う。
- **フォールバック展開は段階的であり、完全一致ではない。** モデルがプレースホルダーの書式を変えた場合（例: 理由テキストを変更した場合）、フックは full placeholder → prefix+hash+suffix → hash-only の順に、徐々に単純な一致を試す。hash-only フォールバックでは、不要な `:` や理由テキストなどの見た目上の残骸が残ることがある。この場合は stderr に警告が出力される。
- **ファイル名変更ではプレースホルダーが残る。** モデルがシェルコマンドでファイル名を変更または移動した場合、新しいファイルには `BLOCK_<hash>` プレースホルダーが残る。セッション停止時、元のコードは `<old-filename>.recovered` として保存される。復旧したコードを新しいファイルへ手動で戻す必要がある。

## 要件

- `jq`、`shasum` または `sha1sum`（自動検出）、Bash 3.2+
