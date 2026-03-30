# TODO

## Parser
- [x] S式をパースして AST にする
- [x] `#!` 付きスクリプトの先頭行を無視する
- [x] `;` コメントを無視する
- [x] `BigDecimal` リテラルを扱う
- [x] 文字列リテラルを扱う
- [ ] エラーメッセージを改善する

## Executor
- [x] bytecode 化検討の設計ドキュメントを作成する
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
- [x] 文字列を扱う組み込み関数を追加する
- [x] `print` で標準出力に値を出せるようにする
- [x] `lambda` で無名関数とクロージャを扱う
- [x] `map` / `reduce` / `fold` / `select` などの高階関数を追加する
- [x] `hash` / `get` / `set` / `entries` で辞書を扱えるようにする
- [x] `keys` / `values` / `has?` を追加する
- [x] `dig` を追加する
- [x] `cons` / `append` / `concat-list` / `nth` / `first` / `rest` を追加する
- [x] `hash-from-pairs` のような配列から辞書への変換を追加する
- [ ] `lambda` の表示とエラーメッセージをさらに改善する

## REPL / File
- [x] ファイル指定で実行する入口を作る
- [x] `:ast` デバッグコマンドを追加する
- [x] `:bytecode` デバッグコマンドを追加する
- [x] `:ast` の表示を YAML 風に整える
- [x] `:help` デバッグコマンドを追加する
- [x] REPL でタブ補完を追加する
- [x] REPL で複数行入力を扱う
- [x] REPL の履歴と終了処理を整える
- [x] REPL で配列の結果を見やすく整形して表示する

## Tests
- [x] Parser の基本テストを追加する
- [x] Executor の基本テストを追加する
- [x] NamespaceRegistry の基本テストを追加する
- [x] コメント付きサンプルのテストを追加する
- [x] `if` のテストを追加する
- [ ] `:ast` コマンドのテストを追加する
- [x] REPL のテストを追加する
- [x] ファイル実行の統合テストを追加する
- [x] 全テストを一括実行できる入口を作る
- [x] stdlib のテストフレームワークを作成する
- [x] `.calc` テストランナーを `bin/calc test` として追加する
- [x] stdlib の全モジュールに `.calc` テストを追加する
