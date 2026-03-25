# agent-gather-github-report

並列初期化ステップで取得した `gh_user` を使用する（再取得しないこと）。

## グローバルアクティビティ（主要ソース）

GraphQL の `contributionsCollection` を使用して、全リポジトリのアクティビティを取得する。これが主要な GitHub データソースであり、コミット、PR、レビュー、Issue を1つのクエリでカバーする。

```bash
gh api graphql -f query='
query {
  viewer {
    contributionsCollection(from: "{date}T00:00:00Z", to: "{next_date}T00:00:00Z") {
      commitContributionsByRepository {
        repository { nameWithOwner }
        contributions { totalCount }
      }
      pullRequestContributions(first: 20) {
        nodes {
          pullRequest {
            title url state number
            repository { nameWithOwner }
          }
        }
      }
      pullRequestReviewContributions(first: 20) {
        nodes {
          pullRequestReview {
            state
            pullRequest {
              title url number
              repository { nameWithOwner }
            }
          }
        }
      }
      issueContributions(first: 20) {
        nodes {
          issue {
            title url number state
            repository { nameWithOwner }
          }
        }
      }
    }
  }
}'
```

## リポジトリごとのコミットメッセージとPR補足（常に取得、可能な限り並列化）

GraphQL クエリはリポジトリごとのコミット数のみを返し、メッセージは返さない。コミットがあるすべてのリポジトリについて**必ず**コミットメッセージを取得すること。リポジトリごとの `gh api` 呼び出しはすべて並列にディスパッチする — ループで直列化しないこと:

```bash
# コミットがある各リポジトリについて — すべて同時にディスパッチ
gh api "repos/{owner}/{repo}/commits?author={gh_user}&since={date}T00:00:00Z&until={next_date}T00:00:00Z" \
  --jq '.[] | "- \(.sha[0:7]) \(.commit.message | split("\n") | .[0])"'
```

**重要**: 「N commits pushed」だけの出力は絶対にしない — コンテキストがない。コミットメッセージを短く読みやすい説明に要約すること（例: 「ログアウトボタンと空状態の表示を追加」）。関連するコミットは1行にまとめる。コミットメッセージの取得に失敗した場合は「- N コミット（詳細取得不可）」と表示。

同じリポジトリについて、PR補足の取得はコミット取得と並行して実行できる — コミットの完了を待つ必要はない:

```bash
# 上記のコミット取得と同時に、同じリポジトリについて実行
gh pr list -R {owner}/{repo} --author @me --search "updated:{date}" \
  --json number,title,state,url --jq '.[] | "- PR #\(.number) \(.title) [\(.state)]"'
```

特定のリポジトリについて GraphQL の PR データが不足している場合にのみ PR 補足を使用する。

## マージと重複排除

1. Claude セッションのリポジトリからのリポジトリごとのデータから開始
2. グローバルアクティビティの項目を追加 — リポジトリごとのクエリで既にカバーされている `owner/repo` はスキップ
3. 残りのグローバル項目は出力の**「その他のリポジトリ」**に配置
4. PR番号 + リポジトリで重複排除
