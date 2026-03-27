# calc

`calc` は Ruby で書かれた S 式ベースの電卓です。REPL とファイル実行の両方に対応していて、`BigDecimal` を使った数値計算、変数定義、`if`、namespace、ユーザー定義関数を扱えます。

## Features

- S 式のパースと評価
- `+`, `-`, `*`, `/` などの基本演算
- `define` による変数・関数定義
- `if` の special form
- namespace によるスコープ分離
- `:ast` と `:help` の REPL コマンド
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

例:

```text
> (+ 1 2 3)
6
> (define x 10)
10
> (+ x 5)
15
> (map (lambda (x) (+ x 1)) (list 1 2 3))
[2, 3, 4]
> (reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))
6
> (select (lambda (x) (> x 1)) (list 1 2 3))
[2, 3]
> ((lambda (x) (+ x 1)) 4)
5
> (namespace fibonacchi
    (define (fib n)
      (if (<= n 1)
          n
          (+ (fib (- n 1)) (fib (- n 2))))))
defined function fibonacchi.fib(n)
> (fibonacchi.fib 10)
55
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

### File execution

```bash
bin/calc path/to/program.calc
```

`#!` で始まる先頭行はスクリプトとして無視されます。

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
