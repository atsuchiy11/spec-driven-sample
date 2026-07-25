# コミットメッセージ規約

本プロジェクトのコミットメッセージは [Conventional Commits](https://www.conventionalcommits.org/ja/v1.0.0/) に従う。

## 形式

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **type**（必須）: 変更の種別。下記の一覧から選ぶ。
- **scope**（任意）: 変更範囲。モジュール名やディレクトリ名など（例: `api`, `spec`, `plan`）。
- **subject**（必須）: 変更内容の要約。
- **body**（任意）: 変更の背景・理由（「何を」より「なぜ」）。
- **footer**（任意）: 破壊的変更や関連 Issue の参照。

## type 一覧

- **feat**: 新機能の追加
- **fix**: バグ修正
- **docs**: ドキュメントのみの変更
- **style**: 挙動に影響しない変更（フォーマット、空白、セミコロンなど）
- **refactor**: 挙動を変えないコード改善（バグ修正でも機能追加でもない）
- **perf**: パフォーマンス改善
- **test**: テストの追加・修正
- **build**: ビルドシステムや依存関係の変更
- **ci**: CI 設定・スクリプトの変更
- **chore**: 上記以外の雑多な変更（ツール設定など）
- **revert**: 以前のコミットの取り消し

## 言語

- コミットメッセージは英語で書く。

## subject のルール

- 英語・命令形・現在形で書く（"add" であって "added"/"adds" ではない）
- 先頭は小文字、文末にピリオドを付けない
- 簡潔にする（目安 50 文字以内）

## body のルール

- 「何を」より「なぜ」を書く（コードを見れば「何を」は分かる）
- 1 行の目安は 72 文字

## 破壊的変更（Breaking Change）

破壊的変更を含む場合は、次のいずれかで示す。

- type の後に `!` を付ける: `feat(api)!: レスポンス形式を変更`
- footer に `BREAKING CHANGE:` を記載する

```
feat(api)!: change response format for TODO retrieval

BREAKING CHANGE: rename `items` to `data`. Existing clients must be updated.
```

## AI 支援時のフッター

AI（Claude Code など）の支援でコミットする場合は、フッターに Co-Authored-By を付与する。

```
Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
```

## 例

```
feat(api): add TODO creation endpoint

Allow registering a new TODO via POST /todos.
Validation: title is required and up to 256 characters.
```

```
docs(plan): add P1 bootstrap implementation plan
```

```
fix(spec): fix missing Given/When/Then mapping in acceptance scenarios
```
