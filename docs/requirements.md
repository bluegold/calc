# Specification

## Overview
This project is a Ruby-based S-expression calculator. It runs as a REPL by default, and it can also execute a program from a file. Script files may start with a `#!` line, which must be ignored during execution.

## Supported Modes
- REPL mode: read expressions from standard input, evaluate them, and print the result
- File mode: load a file and evaluate its contents in order

## Language Features
- Arithmetic: `+`, `-`, `*`, `/`
- Numeric type: `BigDecimal`
- Built-in functions: numeric and utility helpers to be registered in an extensible way
- Variables: users can define and reuse names across expressions in the same session
- Conditionals: `if` as a special form
- Boolean literals: `true`, `false`, and `nil`
- Namespaces: user-defined namespaces plus the reserved `builtin` namespace

## Syntax
- Input uses S-expressions such as `(+ 1 2)`
- Multiple expressions may appear in a file or session
- Comments start with `;` and run to the end of the line
- The first line of a script may be a shebang like `#!/usr/bin/env calc`
- Namespace definitions use a special form such as `(namespace fibonacchi ...)`
- Namespace definitions may use dotted paths such as `(namespace crypto.cipher ...)` to create nested namespaces
- Function lookup prefers the current lexical scope first, then `builtin`, then the current namespace chain, then the reserved `builtin` namespace as a fallback
- Qualified names such as `crypto.twice` resolve directly against the named namespace
- Function and variable names beginning with `_` are local to their namespace and are not resolved from outside it
- Cross-namespace shortcut lookup such as calling `crypto.sha1` from `crypto.cipher` is supported via qualified names

## Error Handling
- Invalid syntax should produce a clear parser error
- Runtime errors, such as division by zero or unknown variables, should be reported clearly
- Use distinct error classes for syntax, name, and runtime failures
- In `if`, only `false` and `nil` are treated as false
- Function arguments and lexical bindings must shadow namespace bindings

## Testing
- Use `minitest` for automated tests
- Add tests for parser behavior, evaluation, variable binding, and REPL/file execution paths
