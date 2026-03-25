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

## Syntax
- Input uses S-expressions such as `(+ 1 2)`
- Multiple expressions may appear in a file or session
- Comments start with `;` and run to the end of the line
- The first line of a script may be a shebang like `#!/usr/bin/env calc`

## Error Handling
- Invalid syntax should produce a clear parser error
- Runtime errors, such as division by zero or unknown variables, should be reported clearly
- Use distinct error classes for syntax, name, and runtime failures

## Testing
- Use `minitest` for automated tests
- Add tests for parser behavior, evaluation, variable binding, and REPL/file execution paths
