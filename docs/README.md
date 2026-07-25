# docs

本プロジェクトの規約・ドキュメントを集約する。

## 配置ルール

- **docs/ 直下に `.md` を置かない**（この README.md のみ例外）。
- ドキュメントは必ず下記のカテゴリディレクトリ配下に置く。
- 該当カテゴリが無い場合は、新しいカテゴリディレクトリを作ってから配置する。

## カテゴリ

| ディレクトリ | 内容 |
| --- | --- |
| `conventions/` | 規約（守るべきルール） |
| `guides/` | 手順・ハウツー |
| `adr/` | アーキテクチャ決定記録（Architecture Decision Record） |
| `architecture/` | 設計・ドメインモデル |

※ 空のカテゴリは先行して作らない。最初の文書が入るときに作成する。

## 索引

### conventions

- [コミットメッセージ規約](./conventions/commit.md) — Conventional Commits に準拠したコミットの書き方（英語）
- [ブランチ命名規約](./conventions/branch.md) — ブランチの命名形式と type
- [プルリクエスト規約](./conventions/pull-request.md) — PR の書き方・マージ戦略（Squash）・レビュー要件

### guides

- [headroom](./guides/headroom.md) — Claude Code のコンテキスト圧縮ツールのセットアップと運用（任意導入・個人環境）
