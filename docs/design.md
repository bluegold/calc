# Design

この文書は「現在の実装設計」を説明する。
`spec.md` は Calc 言語仕様（文法・意味論・言語レベルのエラー）に限定する。
インタプリタ実装/運用仕様（実行モード、CLI オプション、トレース、VM/tree 併存方針）はこの文書の対象とする。

## Positioning

- [docs/requirements.md](docs/requirements.md): 実装前の要件定義（歴史的資料）
- [docs/design.md](docs/design.md): 現行コードベースの設計と責務分割
- [docs/spec.md](docs/spec.md): Calc 言語仕様（インタプリタ運用仕様は含めない）

## Spec Boundary

`spec.md` に書くもの:

- 言語構文（S式、リテラル、special form）
- 評価意味論（truthiness、短絡評価、名前解決ルール）
- 言語として観測されるエラー分類

`design.md` に書くもの:

- 実装構成（Parser/Executer/Compiler/VM/CLI）
- 実行戦略（VM 既定、tree fallback）
- 運用機能（`--trace-vm`、`:trace-vm`、CI モード）

## Runtime Architecture

Calc の評価系は「AST と bytecode VM の併存」構成。

- 既定実行系は VM（`CALC_EXECUTER_MODE=vm`）
- tree-walk は fallback として維持（`CALC_EXECUTER_MODE=tree`）
- 次の大きな言語要素追加で tree-walk の保守が破綻するまで併存方針

主要パイプライン:

1. Source -> Parser -> AST
2. AST -> Compiler -> Bytecode::CodeObject
3. VM 実行（既定）または tree-walk 実行（fallback）

## Core Components

- Parser
  - S式を AST に変換
  - `;` コメントと shebang の処理
  - 位置情報（line/column）を保持

- AST Nodes
  - `NumberNode`, `StringNode`, `KeywordNode`, `SymbolNode`, `ListNode`, `LambdaNode`

- Executer
  - 評価エントリポイント
  - 実行モード切替（vm/tree）
  - 共有ランタイム API（シンボル解決、lambda 呼び出し、namespace/load 操作）
  - エラー文脈付与

- Compiler
  - AST を bytecode へ変換
  - special form をジャンプ命令へ展開
  - lambda の AST body / code body を併存メタで生成

- Vm
  - スタックマシンで命令実行
  - `call`, `jump`, `store`, `make_closure`, `enter_ns`, `load_file` などを実装
  - 命令トレース（`--trace-vm`, `:trace-vm`, `CALC_VM_TRACE`）

- Environment
  - 字句スコープ変数束縛
  - snapshot によるクロージャ捕捉

- NamespaceRegistry
  - namespace 階層とローカル名（`_` 始まり）管理
  - 修飾名/非修飾名の解決

- Builtins
  - 関数レジストリ
  - 型カテゴリや説明などのメタ情報

- CLI / REPL
  - `bin/calc` 入口
  - file 実行、test サブコマンド、bytecode 表示
  - REPL 補助コマンド（`:ast`, `:bytecode`, `:trace-vm`, `:help`）

## Lambda Representation

`LambdaValue` は移行互換のために次を持つ:

- `params`
- `body`（AST body）
- `environment`（定義時スナップショット）
- `namespace`
- `code_body`（VM 用 bytecode body）

`code_body` がある場合は VM 実行、ない場合は tree-walk 実行。

## Error Design

例外分類は以下を維持:

- `Calc::SyntaxError`
- `Calc::NameError`
- `Calc::RuntimeError`
- `Calc::DivisionByZeroError`

file 実行では source path と位置情報を使った文脈付与を行う。

## Traceability and Debugging

- `:ast` で AST 表示
- `:bytecode` / `bin/calc bytecode` で逆アセンブル
- VM trace は bytecode index（`bc[0001]`）を出力し、逆アセンブルと対応づけ可能
- TTY では call/jump/store 等を色付き強調

## Testing Strategy

- 単体: parser, compiler, vm, namespace, builtins
- 統合: file execution, loader, stdlib tests
- 実行モード互換: CI で `vm` と `tree` の両モードを実行

## Non-goals (Current)

- JIT 導入（Ruby VM JIT の利用は任意運用であり、Calc 言語自体の JIT は未実装）
- 並列実行
- 遅延評価モデルへの拡張
