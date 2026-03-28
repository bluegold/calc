# Samples

This directory contains small Calc programs grouped by feature type.

## Syntax and Control Flow

- `basic.calc`: arithmetic, variable definition, `if`, and `print`

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

## Run examples

```bash
bin/calc --print-last-result samples/basic.calc
bin/calc --print-last-result samples/higher-order.calc
bin/calc --print-last-result samples/list-ops.calc
bin/calc --print-last-result samples/hash-ops.calc
```
