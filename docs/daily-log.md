# Daily Log

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
- Added REPL history support via `Readline` and persistent history storage.
- Split Calc exceptions into syntax, name, and runtime classes, and added a dedicated division-by-zero error.
- Marked builtin namespace reservation and division-by-zero handling as complete in the TODO list.
- Added string literals without interpolation, with AST printing and evaluation support.
- Added string helper builtins for concatenation and length.
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
