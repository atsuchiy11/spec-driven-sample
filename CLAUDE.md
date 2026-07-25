# CLAUDE.md

AI エージェント（Claude Code）向けの運用指示。このファイルは薄いハブとして保ち、規約や原則の実体は各参照先（SSoT）に置く。ここには重複を書かない。

## 規約（conventions）

作業時は該当する規約に従う。詳細は各ファイルを参照（SSoT）。

- コミット: [`docs/conventions/commit.md`](./docs/conventions/commit.md)
  - コミットメッセージは **英語**・Conventional Commits 準拠
- ブランチ: [`docs/conventions/branch.md`](./docs/conventions/branch.md)
- プルリクエスト: [`docs/conventions/pull-request.md`](./docs/conventions/pull-request.md)
  - `main` への変更は PR 必須（直 push 禁止）。マージは **Squash**
- 規約の索引: [`docs/README.md`](./docs/README.md)

## プロジェクト原則（constitution）

spec駆動フロー（speckit）の成果物は、プロジェクト憲章に従う。

- 憲章: [`.specify/memory/constitution.md`](./.specify/memory/constitution.md)

## 役割分担

- **CLAUDE.md（本ファイル）**: AI への運用指示。常時有効。参照のみ、重複記載しない。
- **docs/conventions/**: 開発規約の詳細（SSoT）。規約が増えたらここに追加。
- **.specify/memory/constitution.md**: プロジェクトの設計原則。speckit コマンドがゲートとして参照。
