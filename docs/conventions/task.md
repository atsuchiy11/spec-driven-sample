# タスクランナー規約（Taskfile）

本プロジェクトの開発タスク（ビルド・テスト・生成・起動など）は [Taskfile](https://taskfile.dev) に統一する。

## 方針

- プロジェクト全体のタスク実行は **Taskfile 経由**に統一する。
- `go run` / `go generate` / `docker compose` / `npx tsp compile` などの生コマンドを直接叩かず、対応する `task <name>` を使う。
- タスク定義の SSoT は **リポジトリルートの `Taskfile.yml`**。新しい手順が増えたらタスクとしてここに追加する。
- ドキュメント（quickstart など）に手順を書く際は、生コマンドではなく `task <name>` を第一に案内する。

## 導入

```sh
# いずれかの方法で go-task をインストール
brew install go-task
# または
go install github.com/go-task/task/v3/cmd/task@latest
```

## 使い方

```sh
task --list      # タスク一覧
task <name>      # タスク実行（例: task run）
```

## 主要タスク

一覧と説明は `task --list` を正とする。主なものは以下。

- `up` / `down` — PostgreSQL の起動・停止（docker compose）
- `contract` — TypeSpec を openapi.yaml へコンパイル（`contracts/` 配下、要 Node）
- `generate` — oapi-codegen で HTTP 境界コードを生成
- `build` / `run` / `test` — ビルド・API 起動・テスト
- `fmt` / `vet` — フォーマット・静的解析
- `check` — `fmt` + `vet` + `test` の一括実行（CI 想定）

## タスク追加のルール

- 繰り返し使う開発手順は生コマンドのまま放置せず、Taskfile にタスク化する。
- 各タスクには `desc` を付け、`task --list` で用途が分かるようにする。
- タスク名は動詞または対象を表す短い小文字の語にする（例: `run`, `generate`, `contract`）。
