# TODO

## Parser
- [x] S式をパースして AST にする
- [x] `#!` 付きスクリプトの先頭行を無視する
- [x] `;` コメントを無視する
- [x] `BigDecimal` リテラルを扱う
- [x] 文字列リテラルを扱う
- [ ] エラーメッセージを改善する

## Executor
- [x] 四則演算を評価する
- [x] 変数定義を扱う
- [x] `if` を special form として扱う
- [x] namespace の special form を実装する
- [x] `builtin` を予約 namespace として完全に扱う
- [x] namespace 解決順を実装する
- [x] `_` で始まるローカル関数を扱う
- [x] 跨ぎ namespace 参照を qualified name で扱う
- [x] 組み込み関数を登録しやすい構造にする
- [x] `division by zero` の専用エラーを整える
- [x] エラー型を syntax / name / runtime に分ける

## REPL / File
- [x] ファイル指定で実行する入口を作る
- [x] `:ast` デバッグコマンドを追加する
- [x] `:ast` の表示を YAML 風に整える
- [x] `:help` デバッグコマンドを追加する
- [x] REPL で複数行入力を扱う
- [x] REPL の履歴と終了処理を整える

## Tests
- [x] Parser の基本テストを追加する
- [x] Executor の基本テストを追加する
- [x] NamespaceRegistry の基本テストを追加する
- [x] コメント付きサンプルのテストを追加する
- [x] `if` のテストを追加する
- [ ] `:ast` コマンドのテストを追加する
- [ ] REPL のテストを追加する
- [ ] ファイル実行の統合テストを追加する
- [x] 全テストを一括実行できる入口を作る
