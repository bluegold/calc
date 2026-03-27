# Daily Log

## 2026-03-27
- Bumped the project to `0.5.3`.
- Added list helpers: `cons`, `append`, and `concat-list`.
- Added `fold` as a higher-order builtin alongside `reduce`.
- Added `hanoi`/`hanoi2` samples and expanded file execution integration tests.

## 2026-03-27
- Bumped the project to `0.5.2`.
- Refactored builtin definitions into `lib/calc/functions/*` modules.
- Split the large builtin test file into focused test files by domain.

## 2026-03-27
- Added hash/list access helpers: `keys`, `values`, `has?`, `dig`, `nth`, `first`, `rest`, and `hash-from-pairs`.
- Extended `map`, `reduce`, and `select` to accept hash entries as `[:key, value]` pairs.

## 2026-03-27
- Bumped the project to `0.5.1`.
- Fixed `parse-json` to preserve decimal precision with `BigDecimal`.

## 2026-03-27
- Bumped the project to `0.5.0`.
- Added dictionary helpers with `hash`, `get`, `set`, and `entries`, plus JSON parsing and stringifying.

## 2026-03-27
- Added `hash`, `get`, `set`, `entries`, `parse-json`, and `stringify-json` for dictionary and JSON handling.
- Introduced keyword-style hash keys using `:key` syntax.

## 2026-03-27
- Marked the file execution integration test task complete in the TODO list.

## 2026-03-27
- Changed file execution to print the last result only when `--print-last-result` is passed.

## 2026-03-27
- Updated file execution so `bin/calc filename` prints the final expression result like the REPL.

## 2026-03-27
- Added a `samples/` directory with small Calc programs for arithmetic, higher-order functions, recursion, and namespace usage.
- Documented the sample programs in the README.

## 2026-03-27
- Bumped the project to `0.4.2`.
- Formatted list output recursively so higher-order functions like `select` render readable arrays in the REPL.

## 2026-03-27
- Reordered the README examples from simple arithmetic through higher-order functions to recursive namespace usage.
- Noted that `list` is a builtin helper for building arrays rather than a special form.

## 2026-03-26
- Updated the release workflow to keep release notes generic across versions.
- Added `print` and string builtins, plus string literal support.
- Added `lambda` closures, `do`, and sugar for named functions.
- Improved function-call error messages so typos like `labmda` include expression context.
- Added higher-order builtins: `map`, `reduce`, `select`, and `list`.
- Split Calc exceptions into syntax, name, and runtime classes, and added a dedicated division-by-zero error.
- Marked builtin namespace reservation and division-by-zero handling as complete in the TODO list.
- Added multiline REPL input with separate primary and continuation prompts.
- Hardened REPL history loading and saving so filesystem failures do not crash the shell.
- Switched REPL history persistence to JSON so multiline entries survive restarts intact.
- Added a `rake test` entrypoint for running the full test suite.
- Added a first-pass `NamespaceRegistry` for nested namespaces and local-name tracking.
- Unified namespace-qualified function lookup, lexical scope precedence, and qualified names like `crypto.twice`.
- Updated docs and tests to reflect namespace-local variables, local-only `_` names, and namespace-aware resolution.
- Refined resolution order so lexical bindings shadow namespace bindings and qualified lookups stay within their target namespace.
- Added `:help` to the REPL and made history skip failing inputs.
- Added a parser test for sample input with shebang and line comments.
- Bumped the project to `0.3.0` and verified the release automation.

## 2026-03-25
- Initialized the Ruby S-expression calculator repository.
- Added project guidelines and early design notes.
- Switched the test strategy to `minitest`.
- Implemented the first parser and executor skeleton.
- Added basic parser and evaluator tests.
- Started a tracked TODO list for upcoming work.
- Added `BigDecimal` number handling and `;` line comments.
- Updated parser and executor tests to cover the new behavior.
- Added AST pretty printing and a `:ast` REPL debug command.
- Switched `:ast` output to a YAML-like indented representation for readability.
- Implemented the `if` special form.
