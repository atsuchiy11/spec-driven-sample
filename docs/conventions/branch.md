# ブランチ命名規約

## 基本方針

- `main` を唯一の統合ブランチとする。
- `main` への直接 push は禁止。変更は必ずブランチを切り、PR 経由でマージする。
- 作業ごとにブランチを分ける。

## 命名形式

```
<type>/<short-description>
```

- **type**: 作業の種別。コミットの type と揃える。
- **short-description**: 内容の短い説明。英小文字・ハイフン区切り（kebab-case）。

## type 一覧

- **feat/** — 新機能
- **fix/** — バグ修正
- **docs/** — ドキュメントのみ
- **refactor/** — 挙動を変えないコード改善
- **test/** — テスト
- **chore/** — 雑多な変更（ツール設定など）
- **spike/** — 調査・検証・試作（本番投入を前提としない探索）

## 例

```
feat/todo-create-endpoint
fix/spec-acceptance-mapping
docs/commit-convention
spike/speckit
```

## 補足

- ブランチ名は英語で書く。
- マージ済みのブランチは削除してよい（履歴は main と PR に残る）。
