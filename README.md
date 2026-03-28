# calc

`calc` は Ruby で書かれた S 式ベースの電卓です。REPL とファイル実行の両方に対応していて、`BigDecimal` を使った数値計算、変数定義、`if`、namespace、ユーザー定義関数を扱えます。

## Features

- S 式のパースと評価
- `+`, `-`, `*`, `/`, `pow`, `sqrt` などの数値演算
- `define`, `lambda`, `if`, `do` と再帰
- namespace と修飾名呼び出し（例: `crypto.twice`）
- `load` によるモジュール読み込み
- `list` / `map` / `reduce` / `fold` / `select` などの高階関数
- `hash` / `get` / `set` / `dig` などの辞書・コレクション操作
- `:ast` と `:help` の REPL コマンド、タブ補完
- コメント `;` と shebang 行の無視

## Requirements

- Ruby 3.2 以上

## Setup

```bash
bundle install
```

gem として試すなら、ビルドしてローカルに入れられるよ。

```bash
gem build calc.gemspec
gem install ./calc-[version].gem
```

## Usage

### REPL

```bash
bin/calc
```

`bin/calc` は gem の executable としても配布される想定です。

よく使う操作を機能別に並べると次のようになります。

#### 算術・変数・制御フロー

```text
> (+ 1 2 3)
6
> (define x 10)
10
> (if (> x 5) (* x 2) (/ x 2))
20
```

#### 関数・高階関数

```text
> (define (inc n) (+ n 1))
defined function inc(n)
> (map inc (list 1 2 3))
[2, 3, 4]
> (reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3 4))
10
> (select (lambda (x) (> x 2)) (list 1 2 3 4))
[3, 4]
```

#### コレクション（List / Hash）

```text
> (append (list 1 2 3) 4)
[1, 2, 3, 4]
> (hash :name "taro" :age 20)
{"name" => taro, "age" => 20}
> (dig (hash :items (list (hash :name "taro"))) :items 0 :name)
taro
```

#### Namespace と再帰

```text
> (namespace fibonacci
    (define (fib n)
      (if (<= n 1)
          n
          (+ (fib (- n 1)) (fib (- n 2))))))
defined function fibonacci.fib(n)
> (fibonacci.fib 10)
55
```

#### REPL 補助コマンド

```text
> :help
Commands:
  :ast <expr>   Print the AST for an expression
  :help         Show this help

> :ast (+ 1 (* 2 3))
- type: list
  children:
  - type: symbol
    name: "+"
  - type: number
    value: '1'
  - type: list
    children:
    - type: symbol
      name: "*"
    - type: number
      value: '2'
    - type: number
      value: '3'
```

#### タブ補完

- `Tab` で補完、`Tab` 連打で候補を巡回
- `:he` + `Tab` -> `:help`
- `(loa` + `Tab` -> `load`
- `(namespace crypto (def` + `Tab` -> `define`
- `(namespace crypto (tw` + `Tab` -> namespace 文脈に応じた候補

### File execution

```bash
bin/calc --print-last-result path/to/program.calc
```

`#!` で始まる先頭行はスクリプトとして無視されます。
`--print-last-result` を付けると、ファイル実行中の `print` 出力に続けて、最後の式の結果が REPL と同じ形式で標準出力に表示されます（最後の行が最終結果です）。

例:

```bash
$ bin/calc --print-last-result samples/basic.calc
--- basic ---
14
6
14

$ bin/calc --print-last-result samples/higher-order.calc
--- higher-order ---
[2, 3, 4, 5, 6]
15
[3, 4, 5]

$ bin/calc --print-last-result samples/namespace.calc
--- namespace ---
8
16
```

## Samples by Feature

サンプルは [`samples/`](samples/) にあります。機能の種類ごとに選びやすいように整理すると次の通りです。

### 基本構文・制御フロー

- `samples/basic.calc`: 四則演算、変数、`if`、`print`

### 高階関数

- `samples/higher-order.calc`: `map` / `reduce` / `select`

### リスト操作

- `samples/list-ops.calc`: `nth` / `first` / `rest` / `append` / `concat-list`

### 辞書（Hash）操作

- `samples/hash-ops.calc`: `hash` / `get` / `set` / `keys` / `values` / `dig`

### Namespace とスコープ

- `samples/namespace.calc`: namespace 内定義と修飾名呼び出し

### 再帰アルゴリズム

- `samples/recursion.calc`: Fibonacci
- `samples/hanoi.calc`: ハノイの塔（出力中心）
- `samples/hanoi2.calc`: ハノイの塔（`fold` などを使った構成）

### まとめて試すコマンド例

```bash
bin/calc --print-last-result samples/basic.calc
bin/calc --print-last-result samples/higher-order.calc
bin/calc --print-last-result samples/hash-ops.calc
bin/calc --print-last-result samples/namespace.calc
```

## Running tests

```bash
rake test
```

## Project layout

- `bin/calc`: REPL とファイル実行のエントリポイント
- `lib/calc/parser.rb`: AST の構築と AST 表示
- `lib/calc/executer.rb`: 評価ロジック
- `lib/calc/namespace_registry.rb`: namespace 管理
- `test/`: Minitest のテスト

## Notes

- AST 表示の `:ast` はデバッグ用です
- Release 手順は [`docs/release.md`](docs/release.md) を参照してください
- ルートの `docs/TODO.md` に未実装項目をまとめています
