# P1: Bootstrap & Guardrails Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-driven-sample リポジトリの土台を作り、Jira（acli）と Bruno を含む全動線が `/healthz` E2E で疎通する状態に到達する。AIワークフロー本体（commands/agents）はP2、TODO CRUDの仕様駆動実装はP3で行う。

**Architecture:** Clean Architecture寄りのGo構成（domain/usecase/adapter/infra）、OpenAPI を SSoT として oapi-codegen で型・サーバインターフェースを派生、Bruno で API回帰、testcontainers-go で repository統合テスト、`docs/recipes/*.md` で手動 acli/bru 動線をP2への入力として記録、CI（gen-check/lint/layer-check/test/e2e）で全ガードレールを締める。

**Tech Stack:** Go 1.22+ / gin / GORM / PostgreSQL 16 / oapi-codegen v2 / golang-migrate v4 / testcontainers-go / Bruno CLI (@usebruno/cli) / spectral / golangci-lint v2 / gofumpt / goimports / GitHub Actions / acli (atlassian-cli)

---

## Prerequisites（着手前に確認）

- macOS（Apple Silicon想定）、`brew` 利用可
- Go 1.22 以上がインストール済（`go version` で確認）
- Docker daemon（OrbStack または Docker Desktop）起動可能
- `gh` 認証済（atsuchiy11 アカウント）
- `acli` インストール済・Atlassian インスタンスへの認証済
- Bruno GUI インストール済
- Node.js + npm（Bruno CLI 用、`brew install node` 等）
- 作業ディレクトリ: `~/.ghq/github.com/atsuchiy11/spec-driven-sample`
- リポジトリ直近コミット: `cf137cf docs: add design spec for spec-driven-sample (meta)`（main、origin と同期済）

## 全タスク共通の規約

- **Jira プロジェクトキー**: `SDS`（変更したい場合は本プラン全体を find/replace）
- **Epic**: P1全体を1 Epic（`SDS-1` を想定、Task 1で実際のキーを確認し本プランに上書きする）
- **Story**: Phase ごとに 1 Story（A=SDS-2, B=SDS-3, ... I=SDS-10 を想定）
- **ブランチ**: `story/<STORY>-<slug>`（例: `story/SDS-2-jira-foundation`）
- **コミット形式**: `[<STORY>] type(scope): subject`（Conventional Commits + Jiraキー）
- **PR**: Phase ごとに 1 PR、本文に `Closes <STORY>` 付き
- **push 方針**: 各 Phase の最後（PR作成直前）に `git push -u origin <branch>`
- **PR マージ後**: ローカルで `git checkout main && git pull && git branch -d <branch>`
- **作業ディレクトリ**: 全コマンドは `~/.ghq/github.com/atsuchiy11/spec-driven-sample` で実行（絶対パスで指定するか、各セッション冒頭で `cd` する）

---

## File Structure（P1完了時に存在するもの）

### 新規作成

```
.editorconfig
.gitignore
.golangci.yml
.spectral.yaml
.github/workflows/ci.yml
CLAUDE.md
Makefile
docker-compose.yml
go.mod
go.sum
tools/tools.go
oapi-codegen.yaml
cmd/api/main.go
internal/domain/health/health.go
internal/usecase/health/port.go
internal/usecase/health/check.go
internal/adapter/handler/healthz_handler.go
internal/adapter/middleware/recover.go
internal/adapter/middleware/request_id.go
internal/adapter/repository/postgres/health_check.go
internal/adapter/repository/postgres/health_check_test.go
internal/infra/config/config.go
internal/infra/db/db.go
internal/infra/server/server.go
internal/gen/api/server.gen.go      (生成: gin-server + models + embedded-spec を1ファイルに同居)
migrations/000001_init.up.sql
migrations/000001_init.down.sql
openapi/todo-api.yaml
bruno/todo-api/bruno.json
bruno/todo-api/environments/local.bru
bruno/todo-api/healthz.bru
.claude/rules/coding-style.md
.claude/rules/api-design.md
.claude/rules/error-handling.md
.claude/rules/testing.md
.claude/rules/openapi-style.md
.claude/rules/db-conventions.md
.claude/rules/commit-convention.md
.claude/rules/pr-convention.md
.claude/rules/definition-of-done.md
.claude/rules/naming.md
docs/recipes/jira.md
docs/recipes/bruno.md
```

### 変更

```
README.md   ← gh repo create の雛形を上書き
```

責務:
- `.claude/rules/*.md` — 全レイヤから読み取られる単一情報源、書き込みなし
- `openapi/todo-api.yaml` — API契約のSSoT、oapi-codegen と Bruno の上流
- `internal/gen/` — 生成物、手書き禁止
- `internal/domain/` — 純粋Go、外部依存ゼロ、GORMタグ禁止
- `internal/usecase/health/port.go` — Repository interface（consumer-owned、output port）
- `internal/adapter/repository/postgres/` — usecase の Repository を GORM で実装、GORMタグはこの層だけ
- `internal/infra/` — 起動・接続・設定のみ、ビジネスロジック禁止

---

## Phase A: Jira プロジェクト作成と P1 Epic/Story 一括起票

### Task 1: Jira プロジェクト作成と Epic/Story 起票

**Files:**
- なし（Jira側の操作）

このタスクは外部副作用のみ。本プラン上のキー（SDS-1〜SDS-10）が実Jiraと一致しない場合、Task 2 以降の `[SDS-N]` を実際のキーに置換する。

- [ ] **Step 1: Jira プロジェクトを Web UI で作成**

Atlassian の Web UI から新規プロジェクトを作成：
- Name: `Spec-Driven Sample`
- Key: `SDS`
- Type: `Scrum` または `Kanban`（好み）
- Lead: 自分

acli ではプロジェクト作成APIが提供されない版が多いため Web UI 推奨。

- [ ] **Step 2: P1 全体の Epic を作成**

```bash
acli jira issue create \
  --project SDS \
  --type Epic \
  --summary "P1: Bootstrap & Guardrails" \
  --body "Goal: spec-driven-sample の土台と全動線（Jira/Bruno/CI）を /healthz E2E で疎通する状態にする。設計書: docs/superpowers/specs/2026-06-07-spec-driven-sample-design.md"
```

期待: `SDS-1` のような Epic キーが標準出力に表示される。**実キーをメモ**し、本プラン全体の `SDS-1` を実キーに置換。

- [ ] **Step 3: Phase ごとに Story を一括起票**

各 Story を作成（`--epic` で Epic 配下に紐付け）。Phase ごとに1 Story：

```bash
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase A: Jira foundation (this story is its own retro)"
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase B: rules layer + CLAUDE.md"
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase C: Go skeleton + docker-compose"
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase D: OpenAPI + oapi-codegen + /healthz"
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase E: Bruno collection + healthz.bru"
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase F: DB skeleton + golang-migrate + testcontainers"
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase G: Lint configs (golangci-lint + spectral)"
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase H: GitHub Actions CI"
acli jira issue create -p SDS -t Story --epic SDS-1 -s "Phase I: README + recipes"
```

期待: 9 Story キーが順に表示される（想定 SDS-2 〜 SDS-10）。**全キーをメモ**。

注: acli のバージョンによってフラグ名が異なる場合（`--type Story` を `-t Story`、`--epic` が `--parent` 等）。`acli jira issue create --help` で確認。

- [ ] **Step 4: 想定キーとずれていたら本プランを書き換え**

Step 2/3 で得た実キーが SDS-1〜SDS-10 と異なる場合、本プラン (`docs/superpowers/plans/2026-06-07-p1-bootstrap-and-guardrails.md`) を開き、すべての `SDS-N` を実キーに置換してコミット：

```bash
git checkout -b story/SDS-2-jira-foundation
# (エディタで本プランファイル内の SDS-N を実キーに置換)
git add docs/superpowers/plans/2026-06-07-p1-bootstrap-and-guardrails.md
git commit -m "[SDS-2] docs(plan): pin actual Jira issue keys"
```

差分が無ければ（キーが一致したら）スキップしてStep 5へ。

- [ ] **Step 5: Phase A の Story を In Progress に遷移**

```bash
acli jira issue move SDS-2 "In Progress"
```

期待: Stateが In Progress に変わる（acliが成功メッセージを返す）。

### Task 2: `docs/recipes/jira.md` を書く

**Files:**
- Create: `docs/recipes/jira.md`

- [ ] **Step 1: ブランチ作成（Step 4でブランチ作っていなければ）**

```bash
git checkout -b story/SDS-2-jira-foundation 2>/dev/null || git checkout story/SDS-2-jira-foundation
```

- [ ] **Step 2: `docs/recipes/jira.md` を作成**

内容（全文）：

````markdown
# Jira 操作レシピ（acli）

P2 で `.claude/agents/jira-bridge.md` を作るまでの間、本プロジェクトで使う acli コマンドの手動レシピをここに集約する。

## 前提

- acli インストール済み・認証済み
- プロジェクトキー: `SDS`

## よく使うコマンド

### Epic 作成

```bash
acli jira issue create -p SDS -t Epic -s "<summary>" -b "<body>"
```

### Story 作成（Epic 配下）

```bash
acli jira issue create -p SDS -t Story --epic <EPIC-KEY> -s "<summary>"
```

### 状態遷移

```bash
acli jira issue move <KEY> "In Progress"
acli jira issue move <KEY> "Done"
```

### 検索

```bash
acli jira issue list -p SDS -q 'parent = SDS-1 AND status != Done'
```

## ワークフローでの使われ方（P2 で自動化する対象）

| ステージ | コンポーネント | 操作 |
|---|---|---|
| `/spec` 完了時 | jira-bridge | Epic 作成（または既存 Epic に追記） |
| `/plan` 完了時 | jira-bridge | Story を Epic 配下に一括作成 |
| `/implement` 開始時 | jira-bridge | Story を In Progress に遷移 |
| `/implement` PR マージ後 | jira-bridge | Story を Done に遷移 |

## 留意点

- **副作用順序**: ファイル書き込み → OpenAPI 検証 → Jira/GitHub の順（`definition-of-done.md`）
- **dry-run**: jira-bridge は本番呼び出し前に必ず dry-run を先行（P2で実装）
- **冪等性**: 同じ summary の Epic を重複作成しないよう、jira-bridge は既存検索 → なければ作成、を行う

## トラブルシューティング

- 認証切れ: `acli auth login`
- プロジェクトが見つからない: `acli jira project list` で実キーを確認
- フラグが効かない: バージョン依存。`acli <command> --help` で正確なフラグを確認
````

- [ ] **Step 3: コミット**

```bash
git add docs/recipes/jira.md
git commit -m "[SDS-2] docs(recipe): document acli manual flow for jira-bridge spec"
```

### Task 3: `.gitignore` と `.editorconfig`

**Files:**
- Create: `.gitignore`
- Create: `.editorconfig`

- [ ] **Step 1: `.gitignore` を作成**

```
# Build outputs
/bin/
*.test
*.out

# Local env / config
.env
.env.local
*.local

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# Go test/cover
coverage.txt
coverage.html

# AI agent run logs (per docs/superpowers/specs §6.6)
docs/.runs/

# Direnv
.envrc
.direnv/

# Docker volumes (if any local)
data/
```

- [ ] **Step 2: `.editorconfig` を作成**

```
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
indent_style = space
indent_size = 2

[*.go]
indent_style = tab
indent_size = 4

[Makefile]
indent_style = tab

[*.sql]
indent_size = 4
```

- [ ] **Step 3: コミット**

```bash
git add .gitignore .editorconfig
git commit -m "[SDS-2] chore: add .gitignore and .editorconfig"
```

### Task 3.5: Phase A をクローズ

- [ ] **Step 1: push + PR 作成**

```bash
git push -u origin story/SDS-2-jira-foundation
gh pr create --title "[SDS-2] Phase A: Jira foundation" --body "$(cat <<'EOF'
## Summary
- Jira プロジェクト SDS と P1 Epic/Story を一括起票
- `docs/recipes/jira.md` で手動 acli フローを記録（P2 jira-bridge の入力仕様）
- `.gitignore` `.editorconfig` を追加

Closes SDS-2
Related Epic: SDS-1
EOF
)"
```

- [ ] **Step 2: PR マージ後、Story を Done に遷移**

```bash
acli jira issue move SDS-2 "Done"
```

- [ ] **Step 3: main 同期**

```bash
git checkout main && git pull && git branch -d story/SDS-2-jira-foundation
```

---

## Phase B: `.claude/rules/` + `CLAUDE.md`

### Task 4: 10ファイルの rules を作成

**Files:**
- Create: `.claude/rules/coding-style.md`
- Create: `.claude/rules/api-design.md`
- Create: `.claude/rules/error-handling.md`
- Create: `.claude/rules/testing.md`
- Create: `.claude/rules/openapi-style.md`
- Create: `.claude/rules/db-conventions.md`
- Create: `.claude/rules/commit-convention.md`
- Create: `.claude/rules/pr-convention.md`
- Create: `.claude/rules/definition-of-done.md`
- Create: `.claude/rules/naming.md`

- [ ] **Step 1: ブランチ作成 + Story 遷移**

```bash
git checkout -b story/SDS-3-rules-claude
acli jira issue move SDS-3 "In Progress"
```

- [ ] **Step 2: `.claude/rules/coding-style.md` を作成**

````markdown
---
id: coding-style
applies_to: [implement]
severity: error
---

# Coding Style (Go)

## フォーマット
- `gofumpt` 必須（`gofmt` 上位互換）
- `goimports` で import 整列

## 命名
- パッケージ名: 全小文字、複数形避ける（`user` ✓ / `users` ✗）
- ファイル名: snake_case（`todo_repo.go`）
- 公開識別子は doc コメント必須

## エラーラップ
```go
return fmt.Errorf("usecase: create todo: %w", err)
```
- 文頭の文脈（`<package>:<operation>: %w`）必須
- `errors.Is/As` を前提に sentinel/custom struct を用意

## context.Context
- 全public関数の第1引数。命名は `ctx`
- 中で破棄せず goroutine にも伝搬

## グローバル状態禁止
- パッケージレベルの可変状態を作らない
- 設定は `infra/config` から注入

## Dependency Rule（Clean Architecture）
- `domain` → 何も import しない（標準ライブラリのみ可）
- `usecase` → `domain` のみ
- `adapter` → `usecase` + `domain` + `gen/api`
- `infra` → 全部

違反は CI（layer-check ジョブ）で reject。
````

- [ ] **Step 3: `.claude/rules/api-design.md` を作成**

````markdown
---
id: api-design
applies_to: [spec, implement]
severity: error
---

# API Design

## REST 規約
- リソース URI は複数形 (`/todos`、`/todos/{id}`)
- HTTP メソッド: GET/POST/PUT/PATCH/DELETE を意味通りに
- バージョニング: パスprefix `/v1` で開始（将来 `/v2` を追加可能に）

## ステータスコード
- `200 OK` 取得・正常更新
- `201 Created` 作成成功（`Location` ヘッダ必須）
- `204 No Content` 削除成功・更新で本文返さない場合
- `400 Bad Request` リクエスト形式エラー
- `404 Not Found` リソース無し
- `409 Conflict` 重複・状態競合
- `422 Unprocessable Entity` バリデーションエラー（フォーマットOK、意味NG）
- `500 Internal Server Error` 想定外

## レスポンス形状
- 成功: 単一リソースは平坦オブジェクト、一覧は `{ "items": [...], "next_cursor": "..." }` 形式
- エラー: `ErrorResponse` スキーマ（`error-handling.md` 参照）

## ページネーション
- カーソル方式（`?cursor=<opaque>&limit=20`）。オフセットは禁止。

## 日時
- ISO 8601 UTC（`2026-06-07T07:00:00Z`）固定。タイムゾーン付きで返す。
````

- [ ] **Step 4: `.claude/rules/error-handling.md` を作成**

````markdown
---
id: error-handling
applies_to: [implement]
severity: error
---

# Error Handling

## 層別責務
- **domain**: sentinel + custom struct を定義 (`ErrTodoNotFound`, `InvalidTitleError`)
- **usecase**: `fmt.Errorf("%s: %s: %w", pkg, op, err)` で wrap
- **repository**: DB エラーを domain error にマップ（`gorm.ErrRecordNotFound` → `domain.ErrTodoNotFound`）
- **handler**: `errors.As/Is` で domain error を判定 → HTTP

## panic 禁止
- ライブラリの panic はプロセス境界の `recover` middleware で 500 に翻訳
- 自前で panic しない（テストの `t.Fatal` を除く）

## HTTP エラーレスポンス（固定）
```json
{
  "code": "todo_not_found",
  "message": "Todo not found",
  "details": [{ "field": "id", "issue": "no record" }],
  "request_id": "01HXX..."
}
```
- `code` は snake_case
- `request_id` は middleware で context 注入したものを必ず付ける

## エラー → ステータスマップ
| domain error | HTTP |
|---|---|
| ErrNotFound 系 | 404 |
| InvalidXxxError, ValidationError | 422 |
| ConflictError | 409 |
| 想定外 | 500（stack trace を構造化ログ） |

## ログ
- `log/slog` の JSON ハンドラ
- エラー時は `slog.Error` + `slog.Any("err", err)`、500 系は stack trace 同梱
````

- [ ] **Step 5: `.claude/rules/testing.md` を作成**

````markdown
---
id: testing
applies_to: [implement]
severity: error
---

# Testing

## 構造
- ファイル: `<source>_test.go` を同パッケージに配置
- 関数名: `Test<Subject>_<Scenario>` (例: `TestCreateTodo_RejectsEmptyTitle`)
- 必ず table-driven:
```go
tests := []struct{
    name string
    in   InputT
    want OutputT
    err  error
}{
    {name: "happy path", in: ..., want: ...},
    {name: "rejects empty", in: ..., err: domain.ErrInvalidTitle},
}
for _, tc := range tests {
    tc := tc
    t.Run(tc.name, func(t *testing.T) {
        t.Parallel()
        ...
    })
}
```

## モック
- 「使う側パッケージ内で interface 定義」（consumer-owned）
- モック実装は同パッケージ `mock_*_test.go` に手書き or `go:generate mockgen`

## ヘルパ
- `t.Helper()` を必ず呼ぶ
- `t.Cleanup(func(){...})` で後片付け

## ゴールデンファイル
- `testdata/<test_name>.golden.json`
- 更新は `go test -update` フラグで（自前で `var update = flag.Bool("update", false, "")`）

## レイヤごとの戦略
| 層 | 戦略 | DB |
|---|---|---|
| domain | stdlib `testing` | 不要 |
| usecase | Repository モック | 不要 |
| adapter/handler | httptest + usecase モック | 不要 |
| adapter/repository | testcontainers-go + 実 Postgres | 実DB |
| E2E | docker-compose + `bruno run` | 実DB |

## 並列化
- `t.Parallel()` をデフォルト。共有可変状態がある場合のみ外す。
- `go test -race` 必須。

## カバレッジ
- 目標 80% 以上（CI で `-cover` 出力、PR コメントで可視化は将来）
````

- [ ] **Step 6: `.claude/rules/openapi-style.md` を作成**

````markdown
---
id: openapi-style
applies_to: [spec]
severity: error
---

# OpenAPI Style

## 必須要素
- `info.version` を SemVer（`1.0.0`）
- 各 path に `summary`, `description`, `operationId`, `tags` 必須
- `operationId` は camelCase（`createTodo`, `listTodos`）
- すべてのスキーマに `example` または `examples` を1つ以上

## エラースキーマ
- 全 path で `4xx` `5xx` レスポンスとして `ErrorResponse` を参照

## 命名
- スキーマ: PascalCase（`Todo`, `ErrorResponse`）
- プロパティ: snake_case（`created_at`, `request_id`）
- enum 値: snake_case

## ページネーション形状
- リスト系は `{ items: [...], next_cursor: "..." }` 固定（`api-design.md` と一致）

## 検証
- `spectral lint openapi/*.yaml` で `--fail-severity error` 通過必須
- `.spectral.yaml` の Ruleset は spectral:oas に独自追加ルール
````

- [ ] **Step 7: `.claude/rules/db-conventions.md` を作成**

````markdown
---
id: db-conventions
applies_to: [implement]
severity: error
---

# DB Conventions (GORM + golang-migrate + PostgreSQL)

## GORM タグの所在
- `gorm:` タグは `internal/adapter/repository/postgres/` 配下にのみ存在を許可
- `internal/domain` `internal/usecase` に `gorm:` が出現したら CI（layer-check ジョブ）で fail

## domain entity と DB model の分離
- `domain.Todo` は純粋 Go struct（タグなし）
- `internal/adapter/repository/postgres/model.go` に `type dbTodo struct{...}` を別途定義
- 同ファイル内に双方向 mapper `toDomain(dbTodo) domain.Todo` / `fromDomain(domain.Todo) dbTodo`

## マイグレーション
- ツール: `golang-migrate` v4
- 配置: `migrations/<6桁連番>_<snake_case>.up.sql` / `.down.sql`
- **forward-only**: `.down.sql` は空ファイル（または `-- forward-only: see db-conventions.md` のみ）
- ロールバックが必要な場合は **新規マイグレーションで前進**（過去を書き換えない）
- AutoMigrate は使わない（dev も含めて禁止）

## クエリ
- `Preload` 多用禁止（N+1 検出責任は実装者）
- 一覧取得は明示的に `Limit` をかける（デフォルト 20）
- トランザクションは usecase 層で開く（`Repository.RunInTx(ctx, func(...) error)` パターン）

## 接続
- DSN は環境変数 `DATABASE_URL` 経由
- 接続プール: `MaxIdleConns=10`, `MaxOpenConns=50`, `ConnMaxLifetime=5m`
````

- [ ] **Step 8: `.claude/rules/commit-convention.md` を作成**

````markdown
---
id: commit-convention
applies_to: [implement]
severity: error
---

# Commit Convention

## 形式
```
[<STORY>] <type>(<scope>): <subject>
```

- `<STORY>`: Jira Story キー（例: `SDS-5`）。先頭必須。
- `<type>`: Conventional Commits の型
  - `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `build`, `ci`, `style`, `perf`
- `<scope>`: 影響パッケージ／領域（任意、`(handler)`, `(repo)`, `(openapi)` 等）
- `<subject>`: 命令形・小文字始まり・末尾ピリオドなし

## 例
```
[SDS-5] feat(handler): add /healthz handler
[SDS-5] test(handler): cover healthz 200 case
[SDS-5] docs(recipe): document bruno run flow
```

## 1論点1コミット
- 「リファクタ＋機能追加」を1コミットに混ぜない
- 巨大すぎる差分は `git add -p` で分割

## CI 連動
- main 直 push 禁止（PR経由のみ、ブランチ保護で設定推奨）
````

- [ ] **Step 9: `.claude/rules/pr-convention.md` を作成**

````markdown
---
id: pr-convention
applies_to: [implement]
severity: error
---

# PR Convention

## タイトル
```
[<STORY>] <Story summary>
```

## 本文テンプレ
```markdown
## Summary
- <変更の要点を1-3項目>

## Closes
Closes <STORY-KEY>

## Test plan
- [ ] `make gen lint test e2e` が全 pass
- [ ] `bruno run bruno/<area>` の結果を貼付
- [ ] 仕様逸脱の有無を story doc に追記

## Screenshots / Output
（必要なら）
```

## ラベル
- `phase:bootstrap` / `phase:workflow` / `phase:dogfood` 等
- `type:feat` / `type:fix` / `type:docs` を任意で

## レビュー観点
- 仕様（`docs/specs/`）とのズレ
- 層境界（Dependency Rule）違反
- テストカバレッジと観点
- 生成ファイル (`internal/gen/`) を手書きしていないか
````

- [ ] **Step 10: `.claude/rules/definition-of-done.md` を作成**

````markdown
---
id: definition-of-done
applies_to: [all]
severity: error
---

# Definition of Done

## /brainstorm
- `docs/brainstorms/YYYY-MM-DD-<slug>.md` がコミット済み
- `Origin:` フィールドは空でも可

## /spec
- `docs/specs/<EPIC>-<slug>.md` 完成（要件・受け入れ条件・スコープ外）
- `openapi/<area>.yaml` 更新済 + `spectral lint` pass
- Jira Epic 作成済（ファイル先頭バナーにキー）
- `internal/gen/api/*.gen.go` が再生成済（差分があれば PR に含む）
- Draft PR open

## /plan
- `docs/plans/<EPIC>-<slug>.md` 完成
- `docs/stories/<STORY>-<slug>.md` × N が揃う
- 各 Story に Jira キー埋め込み
- Story 間の依存に循環なし
- PR open（spec PR とリンク）

## /implement (Story 単位)
- 該当 Story の受け入れ条件をすべて満たす
- `make gen lint test e2e` 全 pass
- `internal/gen/` に手書き差分なし
- カバレッジ低下なし（理想 80%+）
- story ファイルに「実装メモ / 仕様からの逸脱 / 残課題」追記
- PR が `Closes <STORY>` 付きで open
- マージ後 Jira Story が Done に遷移

## 副作用順序（全段共通）
1. ローカル成果物（ファイル書込）
2. 検証（OpenAPI/lint/test）
3. 外部API（acli/gh）

3 を越えて失敗したら自動ロールバックはしない。状態を提示し、将来の `/recover <epic-key>` の余地を残す。
````

- [ ] **Step 11: `.claude/rules/naming.md` を作成**

````markdown
---
id: naming
applies_to: [all]
severity: warning
---

# Naming

## ブランチ
- `brainstorm/<slug>`
- `spec/<EPIC>-<slug>`
- `plan/<EPIC>-<slug>`
- `story/<STORY>-<slug>`

## slug
- 全小文字、ハイフン区切り、英数字のみ
- 動詞 + 名詞（例: `add-bruno-collection`, `wire-healthz-handler`）

## ファイル
- `docs/brainstorms/YYYY-MM-DD-<slug>.md`
- `docs/specs/<EPIC>-<slug>.md`
- `docs/plans/<EPIC>-<slug>.md`
- `docs/stories/<STORY>-<slug>.md`

## Go パッケージ
- 1単語、小文字、複数形避ける
- `internal/usecase/todo` ↔ パッケージ名 `todo`（重複しても可）

## OpenAPI operationId
- camelCase + 動詞始まり（`createTodo`, `listTodos`, `getTodo`）

## DB
- テーブル名: snake_case 複数形（`todos`）
- カラム: snake_case（`created_at`）
- インデックス: `idx_<table>_<col1>_<col2>`
- 外部キー: `fk_<from_table>_<to_table>`
````

- [ ] **Step 12: 一括コミット**

```bash
git add .claude/rules/
git commit -m "[SDS-3] docs(rules): add 10 foundation rules for all workflow stages"
```

### Task 5: `CLAUDE.md` を作成

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: `CLAUDE.md` を作成**

````markdown
# CLAUDE.md — spec-driven-sample

このリポジトリは「AIによる仕様駆動開発」のサンプル。詳細な設計は `docs/superpowers/specs/2026-06-07-spec-driven-sample-design.md` を参照。

## 必ず最初に読むもの

1. `docs/superpowers/specs/2026-06-07-spec-driven-sample-design.md` — 全体設計
2. `.claude/rules/definition-of-done.md` — 各段階の終了条件
3. `.claude/rules/coding-style.md` — Go コーディング規約と Dependency Rule
4. 該当ステージのコマンド: `.claude/commands/{brainstorm,spec,plan,implement}.md`（P2 で実装）

## ワークフロー（4段）

```
/brainstorm <topic>  (任意・Jira無し)
       ▼
/spec <brainstorm-path | topic>
       ▼
/plan <spec-path>
       ▼
/implement <STORY-KEY>
```

詳細は `docs/superpowers/specs/2026-06-07-spec-driven-sample-design.md §3` を参照。

## 規約サマリ

- Jira プロジェクトキー: `SDS`
- ブランチ: `<stage>/<KEY>-<slug>`（`naming.md`）
- コミット: `[<STORY>] type(scope): subject`（`commit-convention.md`）
- PR: `Closes <STORY>` 必須（`pr-convention.md`）
- OpenAPI は API契約のSSoT。`internal/gen/` への手書きは禁止
- `gorm:` タグは `internal/adapter/repository/postgres/` のみ許可
- マイグレーションは forward-only

## 開発の入口

```bash
make help        # 利用可能なターゲット一覧
make gen         # oapi-codegen 再生成
make lint        # 静的解析一式
make test        # 単体+統合（testcontainers-go）
make e2e         # docker compose + bruno run
```

## 重要な不変条件（CI で守る）

- `internal/gen/` への差分は `gen-check` ジョブで reject
- `internal/domain` / `internal/usecase` への `gorm:` 出現は `layer-check` で reject
- `openapi/*.yaml` の `spectral lint` 違反は `lint` で reject
- `migrations/*.down.sql` に非空SQLが入ったら `layer-check` で reject（forward-only）
````

- [ ] **Step 2: コミット**

```bash
git add CLAUDE.md
git commit -m "[SDS-3] docs: add CLAUDE.md with workflow overview and invariants"
```

### Task 5.5: Phase B をクローズ

- [ ] **Step 1: push + PR 作成**

```bash
git push -u origin story/SDS-3-rules-claude
gh pr create --title "[SDS-3] Phase B: rules layer + CLAUDE.md" --body "$(cat <<'EOF'
## Summary
- `.claude/rules/` 10ファイルを追加（coding-style, api-design, error-handling, testing, openapi-style, db-conventions, commit-convention, pr-convention, definition-of-done, naming）
- `CLAUDE.md` でリポジトリ全体のガイダンスと不変条件を提示

## Closes
Closes SDS-3

## Test plan
- [x] 各 rule に frontmatter (id, applies_to, severity)
- [x] Dependency Rule が coding-style.md に明示
EOF
)"
```

- [ ] **Step 2: マージ後 Story を Done に遷移**

```bash
acli jira issue move SDS-3 "Done"
```

- [ ] **Step 3: main 同期**

```bash
git checkout main && git pull && git branch -d story/SDS-3-rules-claude
```

---

## Phase C: Go skeleton + Docker Compose

### Task 6: `go mod init` + Makefile + cmd/api/main.go スタブ

**Files:**
- Create: `go.mod` / `go.sum`
- Create: `Makefile`
- Create: `cmd/api/main.go`

- [ ] **Step 1: ブランチ作成 + Story 遷移**

```bash
git checkout -b story/SDS-4-go-skeleton
acli jira issue move SDS-4 "In Progress"
```

- [ ] **Step 2: Go モジュール初期化**

```bash
go mod init github.com/atsuchiy11/spec-driven-sample
```

- [ ] **Step 3: `cmd/api/main.go` スタブを作成**

```go
package main

import (
	"fmt"
	"os"
)

func main() {
	fmt.Fprintln(os.Stderr, "spec-driven-sample: not yet wired (see SDS-5)")
	os.Exit(0)
}
```

- [ ] **Step 4: `Makefile` を作成**

```make
.DEFAULT_GOAL := help

.PHONY: help gen lint lint-go lint-spec test test-unit e2e migrate-up migrate-new agent-test run db-up db-down

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

gen: ## Re-generate code (oapi-codegen + bruno managed)
	@echo "TODO: wired in SDS-5 (oapi-codegen) and SDS-6 (bruno)"

lint: lint-go lint-spec ## Run all linters

lint-go: ## gofumpt + goimports + golangci-lint
	@echo "TODO: wired in SDS-8"

lint-spec: ## spectral lint OpenAPI
	@echo "TODO: wired in SDS-8"

test: ## Run all tests (unit + integration with testcontainers-go)
	go test ./... -race -cover

test-unit: ## Run unit tests only (skip -tags=integration)
	go test ./... -race -short

e2e: db-up migrate-up ## docker compose up postgres + run api + bruno run
	@echo "TODO: wired in SDS-9 (CI) — local rehearsal works after Phase F+E"

migrate-up: ## Apply all up migrations
	@echo "TODO: wired in SDS-7"

migrate-new: ## Create new migration files (NAME=<snake_case>)
	@echo "TODO: wired in SDS-7"

run: ## Run API locally (requires postgres up)
	go run ./cmd/api

db-up: ## docker compose up postgres
	docker compose up -d postgres

db-down: ## docker compose down
	docker compose down

agent-test: ## Manual: run agent golden conversation tests (P2)
	@echo "TODO: wired in P2"
```

注: タブインデント必須（Makefile）。

- [ ] **Step 5: ビルドが通ることを確認**

```bash
go build ./...
```

期待: エラーなし。

- [ ] **Step 6: コミット**

```bash
git add go.mod go.sum Makefile cmd/api/main.go
git commit -m "[SDS-4] feat: scaffold go module, Makefile, main stub"
```

### Task 7: `docker-compose.yml`

**Files:**
- Create: `docker-compose.yml`

- [ ] **Step 1: `docker-compose.yml` を作成**

```yaml
services:
  postgres:
    image: postgres:16
    container_name: spec-driven-sample-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: app
      POSTGRES_PASSWORD: app
      POSTGRES_DB: spec_driven_sample
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d spec_driven_sample"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  postgres-data:
```

- [ ] **Step 2: 起動確認**

```bash
docker compose up -d postgres
docker compose ps
```

期待: `postgres` が `healthy` 状態。

- [ ] **Step 3: 接続確認**

```bash
docker compose exec postgres psql -U app -d spec_driven_sample -c 'SELECT 1;'
```

期待: `(1 row)` と返る。

- [ ] **Step 4: 停止**

```bash
docker compose down
```

- [ ] **Step 5: コミット**

```bash
git add docker-compose.yml
git commit -m "[SDS-4] build: add docker-compose.yml with postgres:16"
```

### Task 8: `tools/tools.go` + 開発ツール install

**Files:**
- Create: `tools/tools.go`
- Create: `oapi-codegen.yaml`

- [ ] **Step 1: `tools/tools.go` を作成**

```go
//go:build tools

package tools

import (
	_ "github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen"
	_ "github.com/golang-migrate/migrate/v4/cmd/migrate"
	_ "github.com/golangci/golangci-lint/v2/cmd/golangci-lint"
	_ "mvdan.cc/gofumpt"
	_ "golang.org/x/tools/cmd/goimports"
)
```

- [ ] **Step 2: 依存解決**

```bash
go mod tidy
```

期待: `go.mod` / `go.sum` に上記5ツールが追加される。

- [ ] **Step 3: 開発ツールを install**

```bash
go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen
go install github.com/golang-migrate/migrate/v4/cmd/migrate
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint
go install mvdan.cc/gofumpt
go install golang.org/x/tools/cmd/goimports
```

期待: `$GOPATH/bin` 配下にバイナリが入る（`go env GOPATH` で確認）。

- [ ] **Step 4: `oapi-codegen.yaml` を作成**

```yaml
package: api
output: internal/gen/api/server.gen.go
generate:
  gin-server: true
  models: true
  embedded-spec: true
output-options:
  skip-prune: true
```

(Note: gin-server を有効化することで `ServerInterface` が gin 形式で生成される)

- [ ] **Step 5: コミット**

```bash
git add tools/ oapi-codegen.yaml go.mod go.sum
git commit -m "[SDS-4] build: pin dev tools and add oapi-codegen config"
```

### Task 8.5: Phase C をクローズ

- [ ] **Step 1: push + PR**

```bash
git push -u origin story/SDS-4-go-skeleton
gh pr create --title "[SDS-4] Phase C: Go skeleton + docker-compose" --body "$(cat <<'EOF'
## Summary
- Go module init (`github.com/atsuchiy11/spec-driven-sample`)
- `cmd/api/main.go` スタブ
- `Makefile` の入り口（各ターゲットはTODOプレースホルダで、後続Storyで埋める）
- `docker-compose.yml` (postgres:16 + healthcheck)
- `tools/tools.go` で oapi-codegen / migrate / golangci-lint / gofumpt / goimports を固定
- `oapi-codegen.yaml` 設定

## Closes
Closes SDS-4
EOF
)"
```

- [ ] **Step 2: マージ後**

```bash
acli jira issue move SDS-4 "Done"
git checkout main && git pull && git branch -d story/SDS-4-go-skeleton
```

---

## Phase D: OpenAPI + oapi-codegen + /healthz

### Task 9: OpenAPI 雛形 + /healthz 定義

**Files:**
- Create: `openapi/todo-api.yaml`

- [ ] **Step 1: ブランチ作成 + Story 遷移**

```bash
git checkout -b story/SDS-5-openapi-healthz
acli jira issue move SDS-5 "In Progress"
```

- [ ] **Step 2: `openapi/todo-api.yaml` を作成**

```yaml
openapi: 3.1.0
info:
  title: spec-driven-sample TODO API
  version: 0.1.0
  description: Sample API for spec-driven-development demo
  license:
    name: MIT
servers:
  - url: http://localhost:8080
    description: Local development
tags:
  - name: meta
    description: Service metadata
paths:
  /healthz:
    get:
      operationId: getHealthz
      summary: Liveness probe
      description: Returns 200 when the process is up and the database is reachable.
      tags: [meta]
      responses:
        '200':
          description: Service is healthy
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthStatus'
              examples:
                healthy:
                  value:
                    status: ok
                    request_id: 01HXX0000000000000000
        '500':
          description: Unhealthy
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ErrorResponse'
components:
  schemas:
    HealthStatus:
      type: object
      required: [status, request_id]
      properties:
        status:
          type: string
          enum: [ok]
          example: ok
        request_id:
          type: string
          example: 01HXX0000000000000000
    ErrorResponse:
      type: object
      required: [code, message, request_id]
      properties:
        code:
          type: string
          description: snake_case error code
          example: db_unreachable
        message:
          type: string
          example: database is not reachable
        details:
          type: array
          items:
            $ref: '#/components/schemas/ErrorDetail'
        request_id:
          type: string
          example: 01HXX0000000000000000
    ErrorDetail:
      type: object
      required: [field, issue]
      properties:
        field:
          type: string
          example: id
        issue:
          type: string
          example: no record
```

- [ ] **Step 3: コミット**

```bash
git add openapi/todo-api.yaml
git commit -m "[SDS-5] feat(openapi): scaffold OpenAPI spec with /healthz and shared error schema"
```

### Task 10: `make gen` を本実装

**Files:**
- Modify: `Makefile`（`gen` ターゲット）

- [ ] **Step 1: `Makefile` の `gen` ターゲットを置換**

`gen:` ターゲットの内容を以下に変更：

```make
gen: ## Re-generate code (oapi-codegen + bruno managed)
	@mkdir -p internal/gen/api
	oapi-codegen -config oapi-codegen.yaml openapi/todo-api.yaml
```

- [ ] **Step 2: 実行**

```bash
make gen
```

期待: `internal/gen/api/server.gen.go` が生成され、`ServerInterface` インターフェースと `GetHealthz` メソッドを含む。

- [ ] **Step 3: ビルド確認**

```bash
go build ./...
```

期待: コンパイル成功。

- [ ] **Step 4: コミット**

```bash
git add Makefile internal/gen/
git commit -m "[SDS-5] build(make): wire oapi-codegen via 'make gen'"
```

### Task 11: gin を追加して `cmd/api/main.go` で起動 + healthz handler 実装

**Files:**
- Modify: `cmd/api/main.go`
- Create: `internal/domain/health/health.go`
- Create: `internal/usecase/health/port.go`
- Create: `internal/usecase/health/check.go`
- Create: `internal/adapter/handler/healthz_handler.go`
- Create: `internal/adapter/middleware/request_id.go`
- Create: `internal/adapter/middleware/recover.go`
- Create: `internal/infra/config/config.go`
- Create: `internal/infra/server/server.go`

- [ ] **Step 1: 依存追加**

```bash
go get github.com/gin-gonic/gin
go get github.com/oklog/ulid/v2
```

- [ ] **Step 2: `internal/domain/health/health.go` を作成**

```go
package health

// Status represents the liveness state of the service.
type Status string

const (
	StatusOK Status = "ok"
)
```

- [ ] **Step 3: `internal/usecase/health/port.go` を作成**

```go
package health

import "context"

// Repository is the output port for health probing.
type Repository interface {
	Ping(ctx context.Context) error
}

// InputPort is what the handler depends on.
type InputPort interface {
	Check(ctx context.Context) (Output, error)
}

// Output is the use case result.
type Output struct {
	Status string
}
```

- [ ] **Step 4: `internal/usecase/health/check.go` を作成**

```go
package health

import (
	"context"
	"fmt"

	healthdom "github.com/atsuchiy11/spec-driven-sample/internal/domain/health"
)

type Interactor struct {
	repo Repository
}

func NewInteractor(repo Repository) *Interactor {
	return &Interactor{repo: repo}
}

func (i *Interactor) Check(ctx context.Context) (Output, error) {
	if err := i.repo.Ping(ctx); err != nil {
		return Output{}, fmt.Errorf("usecase health: ping: %w", err)
	}
	return Output{Status: string(healthdom.StatusOK)}, nil
}
```

- [ ] **Step 5: `internal/adapter/middleware/request_id.go` を作成**

```go
package middleware

import (
	"context"
	cryptorand "crypto/rand"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/oklog/ulid/v2"
)

type requestIDKey struct{}

// RequestID injects a ULID into context and X-Request-Id header.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader("X-Request-Id")
		if id == "" {
			id = ulid.MustNew(ulid.Timestamp(time.Now()), cryptorand.Reader).String()
		}
		ctx := context.WithValue(c.Request.Context(), requestIDKey{}, id)
		c.Request = c.Request.WithContext(ctx)
		c.Header("X-Request-Id", id)
		c.Next()
	}
}

// FromContext extracts the request id (empty if absent).
func FromContext(ctx context.Context) string {
	v, _ := ctx.Value(requestIDKey{}).(string)
	return v
}
```

- [ ] **Step 6: `internal/adapter/middleware/recover.go` を作成**

```go
package middleware

import (
	"log/slog"
	"net/http"
	"runtime/debug"

	"github.com/gin-gonic/gin"
)

// Recover converts panics into structured 500 responses.
func Recover(logger *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if r := recover(); r != nil {
				logger.ErrorContext(c.Request.Context(), "panic recovered",
					slog.Any("panic", r),
					slog.String("stack", string(debug.Stack())),
				)
				c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
					"code":       "internal_error",
					"message":    "unexpected error",
					"request_id": FromContext(c.Request.Context()),
				})
			}
		}()
		c.Next()
	}
}
```

- [ ] **Step 7: `internal/adapter/handler/healthz_handler.go` を作成**

```go
package handler

import (
	"net/http"

	"github.com/gin-gonic/gin"

	api "github.com/atsuchiy11/spec-driven-sample/internal/gen/api"
	"github.com/atsuchiy11/spec-driven-sample/internal/adapter/middleware"
	"github.com/atsuchiy11/spec-driven-sample/internal/usecase/health"
)

// Server implements api.ServerInterface.
type Server struct {
	Health health.InputPort
}

func NewServer(healthIn health.InputPort) *Server {
	return &Server{Health: healthIn}
}

// GetHealthz satisfies api.ServerInterface.
func (s *Server) GetHealthz(c *gin.Context) {
	out, err := s.Health.Check(c.Request.Context())
	reqID := middleware.FromContext(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, api.ErrorResponse{
			Code:      "db_unreachable",
			Message:   "database is not reachable",
			RequestId: reqID,
		})
		return
	}
	c.JSON(http.StatusOK, api.HealthStatus{
		Status:    api.HealthStatusStatus(out.Status),
		RequestId: reqID,
	})
}
```

注: oapi-codegen が生成する型名（`HealthStatusStatus` 等）は実生成物を確認して合わせる。コンパイル時に名前ミスマッチがあったら実生成名に置き換える。

- [ ] **Step 8: `internal/infra/config/config.go` を作成**

```go
package config

import (
	"os"
)

type Config struct {
	HTTPAddr    string
	DatabaseURL string
}

func Load() Config {
	return Config{
		HTTPAddr:    getenv("HTTP_ADDR", ":8080"),
		DatabaseURL: getenv("DATABASE_URL", "postgres://app:app@localhost:5432/spec_driven_sample?sslmode=disable"),
	}
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
```

- [ ] **Step 9: `internal/infra/server/server.go` を作成**

```go
package server

import (
	"log/slog"

	"github.com/gin-gonic/gin"

	api "github.com/atsuchiy11/spec-driven-sample/internal/gen/api"
	"github.com/atsuchiy11/spec-driven-sample/internal/adapter/handler"
	"github.com/atsuchiy11/spec-driven-sample/internal/adapter/middleware"
	"github.com/atsuchiy11/spec-driven-sample/internal/usecase/health"
)

func New(logger *slog.Logger, healthIn health.InputPort) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(middleware.RequestID(), middleware.Recover(logger))

	srv := handler.NewServer(healthIn)
	api.RegisterHandlers(r, srv)

	return r
}
```

注: `api.RegisterHandlers` の正確なシグネチャは oapi-codegen の生成物に依存。生成後に確認して合わせる。

- [ ] **Step 10: `cmd/api/main.go` を本実装**

```go
package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/atsuchiy11/spec-driven-sample/internal/infra/config"
	"github.com/atsuchiy11/spec-driven-sample/internal/infra/server"
	"github.com/atsuchiy11/spec-driven-sample/internal/usecase/health"
)

// stubHealthRepo は Phase F で DB 実装に差し替える。
type stubHealthRepo struct{}

func (stubHealthRepo) Ping(context.Context) error { return nil }

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg := config.Load()
	healthIn := health.NewInteractor(stubHealthRepo{})

	engine := server.New(logger, healthIn)
	httpSrv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           engine,
		ReadHeaderTimeout: 5 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("starting http server", slog.String("addr", cfg.HTTPAddr))
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("http server error", slog.Any("err", err))
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	logger.Info("shutting down")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpSrv.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown failed", slog.Any("err", err))
		os.Exit(1)
	}
}
```

- [ ] **Step 11: ビルド + 動作確認**

```bash
go mod tidy
go build ./...
go run ./cmd/api &
sleep 1
curl -s -i http://localhost:8080/healthz
kill %1
```

期待:
- `HTTP/1.1 200 OK`
- レスポンスJSON `{"status":"ok","request_id":"..."}`

注: 万一型名が合わない（`HealthStatus` のフィールド名が小文字 `status` か `Status` か等）はコンパイルエラーが教えてくれる。`internal/gen/api/types.gen.go` を読んで合わせる。

- [ ] **Step 12: コミット**

```bash
git add cmd/ internal/ go.mod go.sum
git commit -m "[SDS-5] feat: wire gin engine, /healthz handler, request-id and recover middleware"
```

### Task 12: Phase D をクローズ

- [ ] **Step 1: push + PR**

```bash
git push -u origin story/SDS-5-openapi-healthz
gh pr create --title "[SDS-5] Phase D: OpenAPI + oapi-codegen + /healthz" --body "$(cat <<'EOF'
## Summary
- `openapi/todo-api.yaml` の雛形と /healthz, ErrorResponse スキーマ
- `make gen` で oapi-codegen を回す
- gin engine 構築 (`internal/infra/server`)
- `request-id` + `recover` middleware
- Clean Architecture skeleton で /healthz を実装（domain/usecase/adapter）
- `cmd/api/main.go` で起動・graceful shutdown 実装

## Closes
Closes SDS-5

## Test plan
- [x] `make gen` で internal/gen/api/*.gen.go が生成される
- [x] `go run ./cmd/api` 後 `curl localhost:8080/healthz` で 200 + ULID付きJSON
EOF
)"
```

- [ ] **Step 2: マージ後**

```bash
acli jira issue move SDS-5 "Done"
git checkout main && git pull && git branch -d story/SDS-5-openapi-healthz
```

---

## Phase E: Bruno collection + healthz.bru

### Task 13: Bruno CLI install + collection 作成

**Files:**
- Create: `bruno/todo-api/bruno.json`
- Create: `bruno/todo-api/environments/local.bru`
- Create: `bruno/todo-api/healthz.bru`

- [ ] **Step 1: ブランチ作成 + Story 遷移**

```bash
git checkout -b story/SDS-6-bruno-collection
acli jira issue move SDS-6 "In Progress"
```

- [ ] **Step 2: Bruno CLI を install**

```bash
npm install -g @usebruno/cli
bru --version
```

期待: バージョン文字列が表示される（例: `1.x.x`）。失敗時は `node -v` で Node が入っているか確認。

- [ ] **Step 3: `bruno/todo-api/bruno.json` を作成**

```json
{
  "version": "1",
  "name": "todo-api",
  "type": "collection",
  "ignore": [
    "node_modules",
    ".git"
  ]
}
```

- [ ] **Step 4: `bruno/todo-api/environments/local.bru` を作成**

```
vars {
  baseUrl: http://localhost:8080
}
```

- [ ] **Step 5: `bruno/todo-api/healthz.bru` を作成**

```
# managed: true
meta {
  name: GET healthz
  type: http
  seq: 1
}

get {
  url: {{baseUrl}}/healthz
  body: none
  auth: none
}

assert {
  res.status: eq 200
  res.body.status: eq ok
  res.headers["x-request-id"]: matches "^[0-9A-HJKMNP-TV-Z]{26}$"
}

tests {
  test("returns ok status", function() {
    expect(res.getBody().status).to.equal("ok");
  });
}
```

注: 先頭の `# managed: true` フラグは P2 で `bruno-runner` が OpenAPI から再生成して良いかの判定に使う（仕様 §5.3）。

- [ ] **Step 6: ローカル実行確認（手動）**

この時点では `cmd/api/main.go` がまだスタブ Repository を使っているため DB は不要。スタブ healthz サーバを立てて Bruno を当てる：

```bash
go run ./cmd/api &
sleep 1
bru run --env local bruno/todo-api
kill %1
```

期待: `1 passed, 0 failed` 等の Summary。`make e2e` の本実装は DB が実DBに切り替わる Phase F (Task 15) で行う。

- [ ] **Step 7: コミット**

```bash
git add bruno/
git commit -m "[SDS-6] feat(bruno): add collection with healthz request and managed flag"
```

### Task 14: `docs/recipes/bruno.md` を作成

**Files:**
- Create: `docs/recipes/bruno.md`

- [ ] **Step 1: `docs/recipes/bruno.md` を作成**

````markdown
# Bruno 操作レシピ

P2 で `.claude/agents/bruno-runner.md` を作るまでの、Bruno コレクション運用の手動レシピ。

## 前提
- Bruno GUI と CLI (@usebruno/cli) インストール済み
- コレクション: `bruno/todo-api/`

## ローカルで叩く

### GUI
- Bruno GUI を起動 → "Open Collection" → `bruno/todo-api/` を選択
- 環境を `local` に設定

### CLI
```bash
bru run --env local bruno/todo-api
```

特定リクエストだけ:
```bash
bru run --env local bruno/todo-api/healthz.bru
```

## `# managed:` フラグ

各 `.bru` の冒頭 1 行目に必須:
- `# managed: true` — OpenAPI から再生成可。bruno-runner が上書き提案
- `# managed: false` — 手書き保護。再生成スキップ

## アサーション規約
- HTTP ステータス: `res.status: eq <N>`
- JSON フィールド: `res.body.<path>: eq <value>` または `matches <regex>`
- ヘッダ: `res.headers["x-...": ...`
- 機能テストは `tests {}` ブロックに mocha 風で

## ワークフローでの使われ方（P2 で自動化）
- `/spec` 完了時: OpenAPI 差分から `.bru` を再生成（managed のみ、差分提示してユーザー承認）
- `/implement` 中: 実装中に `bru run` を呼んで E2E 検証

## トラブルシューティング
- `bru: command not found` → `npm install -g @usebruno/cli`
- 接続拒否 → `make db-up && go run ./cmd/api` で server を立てる
- アサーション失敗 → `bru run --env local bruno/todo-api --reporter-html out.html` で詳細
````

- [ ] **Step 2: コミット**

```bash
git add docs/recipes/bruno.md
git commit -m "[SDS-6] docs(recipe): document bruno CLI flow for bruno-runner spec"
```

### Task 14.5: Phase E をクローズ

- [ ] **Step 1: push + PR**

```bash
git push -u origin story/SDS-6-bruno-collection
gh pr create --title "[SDS-6] Phase E: Bruno collection + healthz.bru" --body "$(cat <<'EOF'
## Summary
- `bruno/todo-api/` コレクション初期化 (`bruno.json`, `environments/local.bru`, `healthz.bru`)
- `# managed: true/false` フラグ規約を実装
- `docs/recipes/bruno.md` で手動フローを記録（P2 bruno-runner の入力仕様）
- 注: `make e2e` 本実装は Phase F (SDS-7) で DB が実 DB に切り替わるタイミングに合わせる

## Closes
Closes SDS-6

## Test plan
- [x] スタブサーバ起動下で `bru run --env local bruno/todo-api` が `1 passed`
EOF
)"
```

- [ ] **Step 2: マージ後**

```bash
acli jira issue move SDS-6 "Done"
git checkout main && git pull && git branch -d story/SDS-6-bruno-collection
```

---

## Phase F: DB 接続 + golang-migrate + testcontainers-go smoke

### Task 15: マイグレーション + GORM 接続 + healthz repo 差し替え

**Files:**
- Create: `migrations/000001_init.up.sql`
- Create: `migrations/000001_init.down.sql`
- Create: `internal/infra/db/db.go`
- Create: `internal/adapter/repository/postgres/health_check.go`
- Modify: `cmd/api/main.go`
- Modify: `Makefile`

- [ ] **Step 1: ブランチ作成 + Story 遷移**

```bash
git checkout -b story/SDS-7-db-migrations
acli jira issue move SDS-7 "In Progress"
```

- [ ] **Step 2: 初期マイグレーションを作成**

`migrations/000001_init.up.sql`:
```sql
-- Initial migration: placeholder for future todos table (P3).
-- Phase F intentionally creates NO domain tables — only confirms migration plumbing works.

CREATE TABLE IF NOT EXISTS schema_health_check (
    id          serial PRIMARY KEY,
    created_at  timestamptz NOT NULL DEFAULT now()
);
```

`migrations/000001_init.down.sql`:
```sql
-- forward-only: see .claude/rules/db-conventions.md
```

- [ ] **Step 3: `Makefile` の `migrate-up` / `migrate-new` を本実装**

`migrate-up:` を置換：
```make
migrate-up: ## Apply all up migrations
	migrate -path migrations -database "$${DATABASE_URL:-postgres://app:app@localhost:5432/spec_driven_sample?sslmode=disable}" up
```

`migrate-new:` を置換（パラメータ `NAME=` を受け取る）：
```make
migrate-new: ## Create new migration files (NAME=<snake_case>)
	@test -n "$(NAME)" || (echo "NAME=<snake_case> required" && exit 1)
	migrate create -ext sql -dir migrations -seq $(NAME)
```

- [ ] **Step 4: ローカル動作確認**

```bash
make db-up
./scripts/wait-postgres.sh
make migrate-up
docker compose exec postgres psql -U app -d spec_driven_sample -c "\dt"
```

期待: `schema_health_check` テーブルが表示される。

- [ ] **Step 5: `internal/infra/db/db.go` を作成**

```go
package db

import (
	"context"
	"fmt"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type Pool struct {
	*gorm.DB
}

func Open(ctx context.Context, dsn string) (*Pool, error) {
	gormDB, err := gorm.Open(postgres.Open(dsn), &gorm.Config{
		TranslateError: true,
	})
	if err != nil {
		return nil, fmt.Errorf("infra db: open: %w", err)
	}
	sqlDB, err := gormDB.DB()
	if err != nil {
		return nil, fmt.Errorf("infra db: handle: %w", err)
	}
	sqlDB.SetMaxIdleConns(10)
	sqlDB.SetMaxOpenConns(50)
	sqlDB.SetConnMaxLifetime(5 * time.Minute)
	if err := sqlDB.PingContext(ctx); err != nil {
		return nil, fmt.Errorf("infra db: ping: %w", err)
	}
	return &Pool{gormDB}, nil
}
```

- [ ] **Step 6: 依存追加**

```bash
go get gorm.io/gorm
go get gorm.io/driver/postgres
go mod tidy
```

- [ ] **Step 7: `internal/adapter/repository/postgres/health_check.go` を作成**

```go
package postgres

import (
	"context"
	"fmt"

	"gorm.io/gorm"

	"github.com/atsuchiy11/spec-driven-sample/internal/usecase/health"
)

type HealthCheckRepo struct {
	db *gorm.DB
}

func NewHealthCheckRepo(db *gorm.DB) *HealthCheckRepo {
	return &HealthCheckRepo{db: db}
}

// Compile-time check.
var _ health.Repository = (*HealthCheckRepo)(nil)

func (r *HealthCheckRepo) Ping(ctx context.Context) error {
	sqlDB, err := r.db.WithContext(ctx).DB()
	if err != nil {
		return fmt.Errorf("repository postgres: handle: %w", err)
	}
	if err := sqlDB.PingContext(ctx); err != nil {
		return fmt.Errorf("repository postgres: ping: %w", err)
	}
	return nil
}
```

- [ ] **Step 8: `cmd/api/main.go` のスタブを差し替え**

`stubHealthRepo` を削除し、`db.Open` で接続して `postgres.NewHealthCheckRepo(pool.DB)` を渡す形に。修正後の `main` 関数：

```go
func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	cfg := config.Load()

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	pool, err := db.Open(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("db open failed", slog.Any("err", err))
		os.Exit(1)
	}

	healthRepo := pgrepo.NewHealthCheckRepo(pool.DB)
	healthIn := health.NewInteractor(healthRepo)

	engine := server.New(logger, healthIn)
	httpSrv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           engine,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		logger.Info("starting http server", slog.String("addr", cfg.HTTPAddr))
		if err := httpSrv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("http server error", slog.Any("err", err))
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	logger.Info("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := httpSrv.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown failed", slog.Any("err", err))
		os.Exit(1)
	}
}
```

import 追加:
```go
import (
	// 既存に加えて:
	"github.com/atsuchiy11/spec-driven-sample/internal/infra/db"
	pgrepo "github.com/atsuchiy11/spec-driven-sample/internal/adapter/repository/postgres"
)
```

`stubHealthRepo` 型と空Ping実装は削除。

- [ ] **Step 9: ビルド + 起動確認**

```bash
go build ./...
make db-up && ./scripts/wait-postgres.sh && make migrate-up
go run ./cmd/api &
sleep 1
curl -s -i http://localhost:8080/healthz
kill %1
make db-down
```

期待: `200 OK` + JSON。

- [ ] **Step 10: `scripts/wait-postgres.sh` を作成**

```bash
mkdir -p scripts
cat > scripts/wait-postgres.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for i in {1..30}; do
  if docker compose exec -T postgres pg_isready -U app -d spec_driven_sample >/dev/null 2>&1; then
    echo "postgres ready"
    exit 0
  fi
  sleep 1
done
echo "postgres did not become ready" >&2
exit 1
EOF
chmod +x scripts/wait-postgres.sh
```

- [ ] **Step 11: `Makefile` の `e2e` ターゲットを本実装**

`e2e:` ターゲットを以下に置換：

```make
e2e: ## docker compose up postgres + migrate + run api + bruno run
	@echo "Starting postgres..."
	@docker compose up -d postgres
	@./scripts/wait-postgres.sh
	@DATABASE_URL="postgres://app:app@localhost:5432/spec_driven_sample?sslmode=disable" $(MAKE) migrate-up
	@DATABASE_URL="postgres://app:app@localhost:5432/spec_driven_sample?sslmode=disable" go run ./cmd/api & echo $$! > /tmp/sds-api.pid; sleep 2
	@bru run --env local bruno/todo-api; status=$$?; \
		kill $$(cat /tmp/sds-api.pid) 2>/dev/null || true; \
		rm -f /tmp/sds-api.pid; \
		docker compose down; \
		exit $$status
```

- [ ] **Step 12: `make e2e` 通しリハーサル**

```bash
make e2e
```

期待: postgres 起動 → migrate 適用 → API 起動 → bruno が `1 passed` → API kill → postgres down → exit 0。

- [ ] **Step 13: コミット**

```bash
git add migrations/ Makefile internal/ cmd/ scripts/ go.mod go.sum
git commit -m "[SDS-7] feat(db): wire postgres pool, migrations, real healthz Ping, and 'make e2e'"
```

### Task 16: testcontainers-go smoke テスト

**Files:**
- Create: `internal/adapter/repository/postgres/health_check_test.go`

- [ ] **Step 1: 依存追加**

```bash
go get github.com/testcontainers/testcontainers-go
go get github.com/testcontainers/testcontainers-go/modules/postgres
go mod tidy
```

- [ ] **Step 2: テストを作成**

```go
package postgres_test

import (
	"context"
	"testing"
	"time"

	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"

	pgrepo "github.com/atsuchiy11/spec-driven-sample/internal/adapter/repository/postgres"
)

func TestHealthCheckRepo_Ping_ConnectsToRealPostgres(t *testing.T) {
	t.Parallel()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	ctr, err := tcpostgres.Run(ctx, "postgres:16",
		tcpostgres.WithDatabase("test"),
		tcpostgres.WithUsername("test"),
		tcpostgres.WithPassword("test"),
		tcpostgres.BasicWaitStrategies(),
		tcpostgres.WithSQLDriver("postgres"),
	)
	if err != nil {
		t.Fatalf("start postgres: %v", err)
	}
	t.Cleanup(func() {
		_ = ctr.Terminate(ctx)
	})

	dsn, err := ctr.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("connection string: %v", err)
	}

	gdb, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatalf("gorm open: %v", err)
	}
	sqlDB, err := gdb.DB()
	if err != nil {
		t.Fatalf("sql DB handle: %v", err)
	}
	t.Cleanup(func() { _ = sqlDB.Close() })

	// extra: wait briefly for the container to be ready beyond the wait strategy.
	_ = wait.ForLog("database system is ready to accept connections")

	repo := pgrepo.NewHealthCheckRepo(gdb)

	tests := []struct {
		name string
	}{
		{name: "ping returns nil against real postgres"},
	}
	for _, tc := range tests {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Helper()
			if err := repo.Ping(ctx); err != nil {
				t.Fatalf("Ping returned error: %v", err)
			}
		})
	}
}
```

- [ ] **Step 3: 実行**

```bash
go test ./internal/adapter/repository/postgres/... -race -v
```

期待: `PASS`（初回は postgres:16 イメージの pull に数十秒〜数分）。失敗時は Docker daemon が動いているか確認。

- [ ] **Step 4: コミット**

```bash
git add internal/adapter/repository/postgres/health_check_test.go go.mod go.sum
git commit -m "[SDS-7] test(repo): add testcontainers-go smoke test for HealthCheckRepo.Ping"
```

### Task 16.5: Phase F をクローズ

- [ ] **Step 1: push + PR**

```bash
git push -u origin story/SDS-7-db-migrations
gh pr create --title "[SDS-7] Phase F: DB pool + migrations + testcontainers smoke" --body "$(cat <<'EOF'
## Summary
- `migrations/000001_init.{up,down}.sql` (forward-only)
- `make migrate-up` / `make migrate-new` 実装
- `internal/infra/db` で gorm.DB プール
- `internal/adapter/repository/postgres/health_check.go` で `health.Repository` 実装
- スタブ撤去、`cmd/api/main.go` を実 DB 接続版に
- `scripts/wait-postgres.sh` + `make e2e` 本実装（docker compose + migrate + API起動 + bruno run + 後片付け）
- `testcontainers-go` で実 Postgres を起動して Ping を検証する smoke テスト

## Closes
Closes SDS-7

## Test plan
- [x] `make db-up && make migrate-up` が成功
- [x] `go test ./internal/adapter/repository/postgres/... -race` が PASS
- [x] `make e2e` が PASS（reviewer が再確認）
EOF
)"
```

- [ ] **Step 2: マージ後**

```bash
acli jira issue move SDS-7 "Done"
git checkout main && git pull && git branch -d story/SDS-7-db-migrations
```

---

## Phase G: Lint configs (golangci-lint + spectral)

### Task 17: `.golangci.yml` + `.spectral.yaml` + Makefile lint 実装

**Files:**
- Create: `.golangci.yml`
- Create: `.spectral.yaml`
- Modify: `Makefile`（`lint-go`, `lint-spec`）

- [ ] **Step 1: ブランチ作成 + Story 遷移**

```bash
git checkout -b story/SDS-8-lint-configs
acli jira issue move SDS-8 "In Progress"
```

- [ ] **Step 2: `.golangci.yml` を作成**

```yaml
version: "2"
run:
  go: "1.22"
  timeout: 5m
linters:
  default: standard
  enable:
    - bodyclose
    - errcheck
    - gofumpt
    - goimports
    - gosec
    - govet
    - ineffassign
    - misspell
    - revive
    - staticcheck
    - unconvert
    - unparam
    - unused
  settings:
    gofumpt:
      module-path: github.com/atsuchiy11/spec-driven-sample
    goimports:
      local-prefixes:
        - github.com/atsuchiy11/spec-driven-sample
  exclusions:
    rules:
      - path: internal/gen/.*\.go$
        linters: [revive, gosec, unused, errcheck, govet, staticcheck, gofumpt, goimports]
      - path: _test\.go$
        linters: [gosec, errcheck]
```

注: golangci-lint v2 系の設定形式に合わせている。v1 系の場合は `linters-settings` / `issues.exclude-rules` に書き換える。

- [ ] **Step 3: `.spectral.yaml` を作成**

```yaml
extends:
  - spectral:oas
rules:
  operation-tag-defined: error
  operation-operationId: error
  operation-summary: error
  operation-description: warn
  oas3-valid-schema-example: error
```

- [ ] **Step 4: `Makefile` の lint ターゲット実装**

```make
lint-go: ## gofumpt + goimports + golangci-lint
	@gofumpt -d -extra -l $$(find . -type f -name '*.go' -not -path './internal/gen/*' -not -path './tools/*') | tee /tmp/gofumpt.out
	@test ! -s /tmp/gofumpt.out
	@goimports -l -local github.com/atsuchiy11/spec-driven-sample $$(find . -type f -name '*.go' -not -path './internal/gen/*' -not -path './tools/*') | tee /tmp/goimports.out
	@test ! -s /tmp/goimports.out
	@golangci-lint run ./...

lint-spec: ## spectral lint OpenAPI
	@npx --yes @stoplight/spectral-cli lint --fail-severity error openapi/*.yaml
```

- [ ] **Step 5: ローカル実行**

```bash
make lint
```

期待: warning は出ても fail-severity error 違反がなければ exit 0。

- [ ] **Step 6: コミット**

```bash
git add .golangci.yml .spectral.yaml Makefile
git commit -m "[SDS-8] build(lint): add golangci-lint v2 + spectral configs and wire 'make lint'"
```

### Task 17.5: Phase G をクローズ

- [ ] **Step 1: push + PR**

```bash
git push -u origin story/SDS-8-lint-configs
gh pr create --title "[SDS-8] Phase G: Lint configs (golangci-lint + spectral)" --body "$(cat <<'EOF'
## Summary
- `.golangci.yml` (v2 schema, gen を除外、コアな lint 有効化)
- `.spectral.yaml` (oas + 最小の必須ルール)
- `make lint-go` / `make lint-spec` 実装
- `make lint` で両方走る

## Closes
Closes SDS-8

## Test plan
- [x] `make lint` がローカルで PASS
EOF
)"
```

- [ ] **Step 2: マージ後**

```bash
acli jira issue move SDS-8 "Done"
git checkout main && git pull && git branch -d story/SDS-8-lint-configs
```

---

## Phase H: GitHub Actions CI

### Task 18: CI ワークフロー

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: ブランチ作成 + Story 遷移**

```bash
git checkout -b story/SDS-9-github-actions
acli jira issue move SDS-9 "In Progress"
```

- [ ] **Step 2: `.github/workflows/ci.yml` を作成**

```yaml
name: ci

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  gen-check:
    name: gen-check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: stable
      - name: install oapi-codegen
        run: go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen
      - name: regenerate
        run: make gen
      - name: assert no diff
        run: git diff --exit-code

  lint:
    name: lint
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: stable
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
      - name: install lint tools
        run: |
          go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint
          go install mvdan.cc/gofumpt
          go install golang.org/x/tools/cmd/goimports
      - name: lint
        run: make lint

  layer-check:
    name: layer-check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: no gorm tags in domain/usecase
        run: |
          if grep -r 'gorm:' internal/domain internal/usecase 2>/dev/null; then
            echo "ERROR: 'gorm:' tag found outside adapter/repository/postgres" >&2
            exit 1
          fi
      - name: no gen/api imports in domain/usecase
        run: |
          if grep -rE 'gen/api|gorm.io' internal/domain internal/usecase 2>/dev/null; then
            echo "ERROR: forbidden import in domain/usecase" >&2
            exit 1
          fi
      - name: down migrations must be empty
        run: |
          for f in migrations/*.down.sql; do
            if grep -qE '^[^-[:space:]]' "$f"; then
              echo "ERROR: $f contains non-comment SQL (forward-only)" >&2
              exit 1
            fi
          done

  test:
    name: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: stable
      - name: go test
        run: go test ./... -race -cover

  e2e:
    name: e2e
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: app
          POSTGRES_PASSWORD: app
          POSTGRES_DB: spec_driven_sample
        ports:
          - 5432:5432
        options: >-
          --health-cmd="pg_isready -U app -d spec_driven_sample"
          --health-interval=5s --health-timeout=3s --health-retries=10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: stable
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
      - name: install bruno cli
        run: npm install -g @usebruno/cli
      - name: install migrate
        run: go install github.com/golang-migrate/migrate/v4/cmd/migrate
      - name: migrate
        env:
          DATABASE_URL: postgres://app:app@localhost:5432/spec_driven_sample?sslmode=disable
        run: make migrate-up
      - name: start api
        env:
          DATABASE_URL: postgres://app:app@localhost:5432/spec_driven_sample?sslmode=disable
          HTTP_ADDR: ":8080"
        run: |
          go run ./cmd/api &
          echo $! > /tmp/api.pid
          for i in {1..30}; do
            if curl -fsS http://localhost:8080/healthz > /dev/null; then
              echo "api ready"
              exit 0
            fi
            sleep 1
          done
          echo "api did not become ready" >&2
          exit 1
      - name: bruno run
        run: bru run --env local bruno/todo-api
      - name: stop api
        if: always()
        run: kill $(cat /tmp/api.pid) || true
```

注: e2e ジョブは CI 用に service container を使用（`make e2e` はローカル用に docker-compose を使うので別動線）。

- [ ] **Step 3: ローカルで yaml 構文確認**

```bash
docker run --rm -v "$(pwd):/repo" -w /repo rhysd/actionlint:latest -color || true
```

(actionlint が未インストールならスキップ可。GitHub 上で push 後の Actions で確認できればOK)

- [ ] **Step 4: コミット**

```bash
git add .github/
git commit -m "[SDS-9] ci: add github actions (gen-check, lint, layer-check, test, e2e)"
```

### Task 19: CI 動作確認 + 修正

- [ ] **Step 1: push + draft PR**

```bash
git push -u origin story/SDS-9-github-actions
gh pr create --draft --title "[SDS-9] Phase H: GitHub Actions CI" --body "$(cat <<'EOF'
## Summary
- 5ジョブの CI: gen-check / lint / layer-check / test / e2e
- e2e は postgres サービスコンテナで bru run まで実行
- layer-check で gorm タグの所在と forward-only マイグレを CI 守護

## Closes
Closes SDS-9
EOF
)"
```

- [ ] **Step 2: GitHub で CI 結果確認**

```bash
gh pr checks
```

期待: 5ジョブ全て pass。失敗があれば修正してコミット push。

- [ ] **Step 3: 全 pass を確認後 Draft → Ready for review**

```bash
gh pr ready
```

### Task 19.5: Phase H をクローズ

- [ ] **Step 1: マージ後**

```bash
acli jira issue move SDS-9 "Done"
git checkout main && git pull && git branch -d story/SDS-9-github-actions
```

---

## Phase I: README

### Task 20: README を本実装

**Files:**
- Modify: `README.md`

- [ ] **Step 1: ブランチ作成 + Story 遷移**

```bash
git checkout -b story/SDS-10-readme
acli jira issue move SDS-10 "In Progress"
```

- [ ] **Step 2: `README.md` を上書き**

```markdown
# spec-driven-sample

AIによる仕様駆動開発（Spec-Driven Development）のサンプルリポジトリ。Claude Code 上で動く `/brainstorm → /spec → /plan → /implement` の4段階ワークフローを `.claude/` に実装し、サンプルアプリ（TODO REST API: Go + gin + GORM + PostgreSQL）でそのプロセスを実演する。

**主役はアプリではなくワークフロー**。

詳細設計: [`docs/superpowers/specs/2026-06-07-spec-driven-sample-design.md`](docs/superpowers/specs/2026-06-07-spec-driven-sample-design.md)

## ステータス
- [x] **P1: Bootstrap & Guardrails** — リポジトリ土台と全動線（Jira/Bruno/CI）が `/healthz` E2E で疎通
- [ ] **P2: AI Workflow Infrastructure** — `.claude/commands/`, `.claude/agents/`, `.claude/skills/`
- [ ] **P3: Dogfood — TODO CRUD via the workflow** — P2 のワークフローを実行して TODO CRUD を実装、履歴を `docs/` に残す

## 始め方

### 前提
- Go 1.22 以上
- Docker（OrbStack または Docker Desktop）
- Node.js + npm（Bruno CLI 用）
- `gh` 認証済
- （仕様駆動を実演する場合）`acli` インストール・認証済

### セットアップ
```bash
# 開発ツールを GOPATH に install
go install github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen
go install github.com/golang-migrate/migrate/v4/cmd/migrate
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint
go install mvdan.cc/gofumpt
go install golang.org/x/tools/cmd/goimports
npm install -g @usebruno/cli
```

### 動かす
```bash
make help          # 利用可能ターゲット
make db-up         # PostgreSQL を docker compose で起動
make migrate-up    # マイグレーション適用
make run           # API ローカル起動 (localhost:8080)
make e2e           # docker compose + migrate + API + Bruno run を1コマンドで
make test          # unit + testcontainers-go 統合
make lint          # gofumpt + goimports + golangci-lint + spectral
```

確認:
```bash
curl -s http://localhost:8080/healthz | jq
```

## ディレクトリ構成

```
.claude/
  commands/  — オーケストレータ（薄い）
  agents/    — 外部I/O境界 (acli/gh/bru)
  rules/     — 全レイヤ共通の規約
  skills/    — 純関数（テストしやすい）
docs/
  brainstorms/ specs/ plans/ stories/  — ワークフロー出力
  recipes/                              — 手動レシピ
  superpowers/specs/                    — メタ設計
cmd/api/                                — エントリポイント
internal/
  domain/    — 純粋
  usecase/   — application
  adapter/   — handler / middleware / repository
  infra/     — config / db / server
  gen/api/   — oapi-codegen 出力（手書き禁止）
migrations/                             — golang-migrate (forward-only)
openapi/                                — API契約のSSoT
bruno/                                  — E2E コレクション
```

## 規約・ガードレール

- 詳細は `.claude/rules/` 配下を参照
- CI で守る不変条件:
  - `internal/gen/` への手書き差分 → reject (`gen-check`)
  - `internal/domain` / `internal/usecase` に `gorm:` → reject (`layer-check`)
  - `migrations/*.down.sql` の非空SQL → reject（forward-only）
  - OpenAPI spectral 違反 → reject (`lint`)

## ワークフロー（4段）

```
/brainstorm <topic>          (任意・Jira無し)
       ▼
/spec <brainstorm-path | topic>
       ▼
/plan <spec-path>
       ▼
/implement <STORY-KEY>
```

P2 で `.claude/commands/` `.claude/agents/` を実装するまでは、`docs/recipes/jira.md` `docs/recipes/bruno.md` の手動レシピを参照。

## 既知の制限・将来余地

- `/recover` コマンド（副作用後失敗の救済）は未実装、設計書 §10 参照
- 言語は Go のみ（TS/Python 版は別ブランチで提供する余地）
- Jira Sub-task はファイル化せず、Story 内チェックリストで吸収

## License
MIT
```

- [ ] **Step 3: コミット**

```bash
git add README.md
git commit -m "[SDS-10] docs: rewrite README with usage, structure, and roadmap"
```

### Task 20.5: Phase I をクローズ

- [ ] **Step 1: push + PR**

```bash
git push -u origin story/SDS-10-readme
gh pr create --title "[SDS-10] Phase I: README rewrite" --body "$(cat <<'EOF'
## Summary
- `README.md` を本サンプルの実態に合わせて全面書き換え
- ステータス（P1/P2/P3）、セットアップ、ディレクトリ構成、ガードレール、ワークフロー、既知制限

## Closes
Closes SDS-10
EOF
)"
```

- [ ] **Step 2: マージ後**

```bash
acli jira issue move SDS-10 "Done"
git checkout main && git pull && git branch -d story/SDS-10-readme
```

- [ ] **Step 3: Epic を Done に遷移**

```bash
acli jira issue move SDS-1 "Done"
```

---

## P1 完了の Definition of Done（全段共通）

- [x] 9 Story（SDS-2〜SDS-10）すべて Done
- [x] Epic SDS-1 が Done
- [x] main で `make gen lint test e2e` がすべて pass
- [x] CI が全ジョブ green
- [x] `curl localhost:8080/healthz` が 200 + ULID付き JSON を返す
- [x] `bru run --env local bruno/todo-api` が `1 passed`
- [x] `.claude/rules/` が 10 ファイル揃っている
- [x] `docs/recipes/jira.md` `docs/recipes/bruno.md` で手動動線が言語化されている（P2 の入力仕様）

## 次のステップ

P2 の実装計画（`docs/superpowers/plans/<date>-p2-ai-workflow-infrastructure.md`）を `writing-plans` skill で作成する。

P2 のスコープ草案:
- `.claude/skills/` × 3（openapi-validate / jira-key-resolve / rules-lint、それぞれ Go 実装 + ゴールデンテスト）
- `.claude/agents/` × 6（brainstorm-facilitator / spec-author / plan-author / jira-bridge / github-bridge / bruno-runner）
- `.claude/commands/` × 4（brainstorm / spec / plan / implement、`--dry-run` モード含む）
- agents のゴールデン会話テストと `agent-test` Makefile ターゲット
