# Samples

This directory contains small Calc programs that show the kinds of problems the current language can solve.

- `basic.calc`: arithmetic, variable definition, and `if` with step-by-step `print`
- `higher-order.calc`: `map`, `reduce`, and `select` with `print`
- `list-ops.calc`: list access and transformation helpers
- `hash-ops.calc`: hash creation, lookup, update, and traversal helpers
- `hanoi.calc`: recursive Tower of Hanoi move printer
- `hanoi2.calc`: Tower of Hanoi using `cons`, `append`, `concat-list`, and `fold`
- `recursion.calc`: recursive Fibonacci with intermediate output
- `namespace.calc`: namespace-scoped definitions and qualified calls with `print`

## Note on List-Building Helpers

The current runtime can print recursive results (like `hanoi.calc`) but it does not yet include list-building helpers such as `cons`, `append`, `concat-list`, or `fold`.

- `cons`: prepend one item to a list.
- `append`: append one item to the end of a list.
- `concat-list`: concatenate two lists into one.
- `fold`: accumulate values by repeatedly applying a function (similar to `reduce`, but often with argument order and naming aligned to functional programming literature).

These helpers would make it easier to return computed move lists instead of printing each move directly.
