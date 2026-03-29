# Samples

This directory contains small Calc programs grouped by feature type.

## Syntax and Control Flow

- `basic.calc`: arithmetic, variable definition, `if`, `and`, `or`, `not`, `cond`, and `print`

## Higher-Order Functions

- `higher-order.calc`: `map`, `reduce`, and `select`

## Collections

- `list-ops.calc`: list access and transformation helpers
- `hash-ops.calc`: hash creation, lookup, update, and traversal helpers

## Namespace

- `namespace.calc`: namespace-scoped definitions and qualified calls

## Recursion

- `recursion.calc`: recursive Fibonacci with intermediate output
- `hanoi.calc`: recursive Tower of Hanoi move printer
- `hanoi2.calc`: Tower of Hanoi using `cons`, `append`, `concat-list`, and `fold`
- `hanoi3.calc`: Tower of Hanoi using `cond`-based branching
- `nqueen2.calc`: N-Queens solver using `and`/`or`/`not`/`cond`

## stdlib Usage

- `stdlib-list.calc`: `stdlib/collections/list` helpers
- `stdlib-json.calc`: `stdlib/json/core` helpers
- `stdlib-time.calc`: `stdlib/time/core` helpers

## Test Wrappers

- `test/stdlib-list.calc`: sample wrapper for `samples/stdlib-list.calc`
- `test/stdlib-json.calc`: sample wrapper for `samples/stdlib-json.calc`
- `test/stdlib-time.calc`: sample wrapper for `samples/stdlib-time.calc`

## Run examples

```bash
bin/calc --print-last-result samples/basic.calc
bin/calc --print-last-result samples/higher-order.calc
bin/calc --print-last-result samples/list-ops.calc
bin/calc --print-last-result samples/hash-ops.calc
bin/calc --print-last-result samples/hanoi3.calc
bin/calc --print-last-result samples/nqueen2.calc
bin/calc --print-last-result samples/stdlib-list.calc
bin/calc --print-last-result samples/stdlib-json.calc
bin/calc --print-last-result samples/stdlib-time.calc
```
