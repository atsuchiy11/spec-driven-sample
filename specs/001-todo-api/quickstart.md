# クイックスタート / 検証ガイド: TODO 管理 API

**日付**: 2026-07-26 | **対象**: [plan.md](./plan.md) / [contracts/main.tsp](./contracts/main.tsp) / [architecture.md](./architecture.md)

> 本ガイドは実装後（次フェーズ）に API がエンドツーエンドで動くことを検証する手順を示す。実装コードは含まない（実装は `tasks.md` 以降）。

## 前提

- Go 1.26+（`mise.toml` で 1.26.5 固定）
- Docker / Docker Compose（PostgreSQL 16 用）
- Node.js（TypeSpec / Bruno CLI 用のみ。API 本体の実行にも oapi-codegen 生成にも不要 — oapi-codegen は Go tool）
- 環境変数
  - `API_KEY`: 認証キー（例: `dev-secret-key`）
  - `DATABASE_DSN`: PostgreSQL 接続文字列（例: `postgres://todo:todo@localhost:5432/todo?sslmode=disable`）

## 0. API 契約から OpenAPI を生成（TypeSpec）

契約の真実源は `contracts/main.tsp`。OpenAPI はここから生成する。

```sh
cd specs/001-todo-api/contracts
npm install
npx tsp install
npx tsp compile .        # → contracts/openapi.yaml を生成
```

生成された `openapi.yaml` をレビュー/コミットする（詳細は [contracts/README.md](./contracts/README.md)）。

## 0.5. OpenAPI から Go コードを生成（oapi-codegen）

`openapi.yaml` を入力に、handler I/F・DTO・バインドを生成する。

```sh
# ツール導入（初回のみ、go.mod の tool ディレクティブに登録）
go get -tool github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen

# 生成（internal/api/generate.go の //go:generate を起動）
go generate ./...        # → internal/api/todo.gen.go
```

- 生成物 `internal/api/*.gen.go` はコミット済みのため、**通常のビルドでは再生成不要**。契約（`main.tsp` → `openapi.yaml`）を変更したときだけ再実行する。
- Node は不要（oapi-codegen は Go tool）。

## 1. セットアップ（API 起動）

```sh
# PostgreSQL 起動
docker compose up -d

# 環境変数
export API_KEY=dev-secret-key
export DATABASE_DSN='postgres://todo:todo@localhost:5432/todo?sslmode=disable'

# API サーバ起動（起動時に AutoMigrate でスキーマ同期）
go run ./cmd/api
# → http://localhost:8080 で待受
```

## 2. 手動検証（curl、spec の受け入れシナリオに対応）

### 認証（US2）

```sh
curl -i http://localhost:8080/todos                                   # キー無し → 401
curl -i -H "Authorization: Bearer wrong" http://localhost:8080/todos  # 不正キー → 401
```

### 作成（US1 シナリオ 1・2・3・4）

```sh
# 正常 → 201
curl -i -H "Authorization: Bearer dev-secret-key" -H "Content-Type: application/json" \
  -d '{"title":"買い物"}' http://localhost:8080/todos

# title 欠落 → 400（problem+json の errors[] に field=title）
curl -i -H "Authorization: Bearer dev-secret-key" -H "Content-Type: application/json" \
  -d '{}' http://localhost:8080/todos

# completed=true を送っても無視され false で作成される（シナリオ4）
curl -s -H "Authorization: Bearer dev-secret-key" -H "Content-Type: application/json" \
  -d '{"title":"x","completed":true}' http://localhost:8080/todos
```

### 一覧・取得（US1 シナリオ 5・6・7）

```sh
curl -s -H "Authorization: Bearer dev-secret-key" http://localhost:8080/todos      # 200・作成日時降順・空なら []
curl -i -H "Authorization: Bearer dev-secret-key" http://localhost:8080/todos/{id} # 200
curl -i -H "Authorization: Bearer dev-secret-key" \
  http://localhost:8080/todos/00000000-0000-0000-0000-000000000000                 # 404
```

### 更新（US1 シナリオ 8・9）

```sh
# 全項目置換 → 200（completed を false に戻せることを確認 = GORM ゼロ値更新の回避検証）
curl -i -X PUT -H "Authorization: Bearer dev-secret-key" -H "Content-Type: application/json" \
  -d '{"title":"買い物（完了）","description":"牛乳と卵","completed":true}' \
  http://localhost:8080/todos/{id}
```

### 削除（US1 シナリオ 10）

```sh
curl -i -X DELETE -H "Authorization: Bearer dev-secret-key" http://localhost:8080/todos/{id}  # 204
curl -i -H "Authorization: Bearer dev-secret-key" http://localhost:8080/todos/{id}            # 404
```

## 3. 自動テスト（次フェーズで実装）

### Go 単体・結合テスト（testify + testcontainers）

```sh
go test ./...
```

- 単体: usecase の業務ルール（completed 固定・PUT 全置換・意味的 field 検証）を `domain.TodoRepository`（port）モックで検証。
- 結合: `api.RegisterHandlersWithOptions` で束ねた Gin を `httptest` で起動し、認証 MW + 生成 wrapper + handler + usecase + infra/repository を通し、実 PostgreSQL（`testcontainers-go`）で GORM ゼロ値更新の回帰まで検証。
- 成功基準 SC-001〜SC-005（spec）を各テストにマッピングする。

### Bruno による受け入れテスト

```sh
# bruno/ に .bru を配置（各エンドポイント + Authorization ヘッダ）
npx @usebruno/cli run ./bruno --env local --reporter-junit results.xml
```

- 環境ごとに `.bru` 環境ファイルを分離。`API_KEY` はコミットせず環境/CI シークレットから注入。
- 起動済み API に対しブラックボックスで契約整合（ステータス・problem+json・認証）を確認。

## 成功の定義

- 上記 curl / Bruno シナリオがすべて期待ステータスを返す（SC-001〜SC-003, SC-005）。
- `completed` を PUT で false に戻せる（GORM ゼロ値更新問題を踏まない）。
- サーバ再起動後も作成済み Todo を取得できる（SC-004）。
- `contracts/openapi.yaml` が `main.tsp` から再生成でき、実装レスポンスと整合する。
