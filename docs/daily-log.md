# Daily Log

## 2026-03-26
- Updated the release workflow to keep release notes generic across versions.
- Added `print` and string builtins, plus string literal support.
- Added `lambda` closures, `do`, and sugar for named functions.
- Improved function-call error messages so typos like `labmda` include expression context.
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
