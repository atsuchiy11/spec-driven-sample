# API 契約（TypeSpec）

TODO 管理 API の契約は **TypeSpec（`main.tsp`）を SSoT** とし、OpenAPI（`openapi.yaml`）は生成物とする。

## ファイル

- `main.tsp` — API 契約本体（真実源）。編集はここだけ。
- `tspconfig.yaml` — エミッタ設定（出力先 = このディレクトリ、`openapi.yaml`）。
- `package.json` — TypeSpec ツールチェーン（Node/npm）。Go 開発には不要で、この配下に隔離。
- `openapi.yaml` — `tsp compile` の生成物（コミット対象。Node が無くても Go 側が参照できる）。**下流の oapi-codegen（strict-server + Gin）の入力**でもある。

## 生成手順

```sh
cd specs/001-todo-api/contracts
npm install
npx tsp install     # TypeSpec 依存の解決
npx tsp compile .   # → openapi.yaml を生成
```

## Go コード生成（下流）

`openapi.yaml` を入力に、oapi-codegen で Go の HTTP 境界コード（handler I/F・DTO・バインド）を生成する。

- 生成設定: `internal/api/cfg.yaml`（`gin-server` + `strict-server` + `models`）。
- 生成器は go.mod の `tool` ディレクティブで固定（`go get -tool github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen`）。Node は不要（TypeSpec/Bruno とは別系統）。
- 実行: リポジトリルートで `go generate ./...`（`internal/api/generate.go` の `//go:generate` が起動）。
- 生成物 `internal/api/*.gen.go` は**コミット対象**（生成器なしでも Go ビルド可）。

```text
main.tsp ──tsp compile──▶ openapi.yaml ──go generate/oapi-codegen──▶ internal/api/todo.gen.go
```

### operationId と Go メソッド名

TypeSpec の openapi3 エミッタは既定で `interface Todos { create }` を `Todos_create` に出力し、oapi-codegen が `TodosCreate` に写像する。各操作に `@operationId("createTodo")` 等を付ければ `CreateTodo` に短縮できる（**推奨**）。詳細な写像表は [../architecture.md](../architecture.md) のコード生成フロー節。

## 方針（憲章原則 V: YAGNI の歯止め）

- TypeSpec 一式を `contracts/` に隔離し `package.json` を分離。Go 本体のビルドに Node を強制しない。
- 生成物 `openapi.yaml` はリポジトリにコミットする（仕様の可搬性）。
- 生成は独立ジョブ（CI or `npm run build`）に閉じ込める。
- 過剰と判断すれば手書き OpenAPI YAML への後退も容易（生成物と同じ OpenAPI 3.x）。
- **OpenAPI は 3.0.0 を維持**（`tspconfig.yaml` で固定）。oapi-codegen は 3.0 を完全サポート、3.1 は部分対応のため。

## エラー形式

全エラーは RFC 7807 `application/problem+json`。バリデーション（400）は `errors[]`（`field` / `code` / `message`）で不正項目を返す。実装のエラーマッピングは [../architecture.md](../architecture.md) を参照。
