# Calc Language Specification

This document is the reference for Calc syntax and evaluation semantics.
It is intentionally more precise than the README and should be used when
implementing Calc programs or runtime behavior.

## 1. Overview

Calc is an S-expression language implemented in Ruby.

- Programs can run in REPL mode or from a file.
- Expressions are evaluated left to right.
- The primary numeric type is `BigDecimal`.
- Strings, booleans, nil, lists, hashes, keywords, lambdas, and namespaces are supported.

## 2. Source Forms

### 2.1 S-expressions

All Calc code is written as S-expressions.

Examples:

```calc
(+ 1 2 3)
(define x 10)
(if (> x 5) x 0)
```

### 2.2 Comments and shebang

- `;` starts a line comment that runs to the end of the line.
- The first line of a file may be a shebang line and must be ignored.

### 2.3 Literals

- Numbers are parsed as `BigDecimal`.
- Strings are double-quoted.
- Boolean literals are `true` and `false`.
- `nil` is the nil literal.
- Keywords are written with a leading colon, such as `:name`.

## 3. Evaluation Model

### 3.1 Expression order

Expressions are evaluated left to right.
For function calls, arguments are evaluated before the call, except for special forms.

### 3.2 Truthiness

- Only `false` and `nil` are falsey.
- All other values are truthy.
- This includes numeric `0`, empty lists, and empty hashes: they are truthy values.
- When testing length or emptiness, compare explicitly, for example with `> 0` or `== (list)`.
- In particular, an empty list is still truthy and does not behave like `nil`.

### 3.3 Result values

- The result of the last expression is the result of the program or REPL input block.
- In REPL mode, the last evaluated value is printed if it is not `nil`.

## 4. Special Forms

Special forms are not regular functions and control evaluation.

### 4.1 `define`

Defines a variable or function.

- `(define name value)` defines a variable.
- `(define (name params...) body)` defines a function.

Rules:

- Reserved literals cannot be redefined.
- Names beginning with `_` are considered local to their namespace.

### 4.2 `if`

Evaluates only the selected branch.

```calc
(if condition then-expr else-expr)
```

### 4.3 `namespace`

Creates or enters a namespace.

```calc
(namespace crypto
  (define shared 5)
  (define (twice x) (+ x shared)))
```

Rules:

- Nested namespaces may be written with dotted paths, such as `crypto.cipher`.
- Namespace-local names beginning with `_` should not be resolved from outside the namespace.

### 4.4 `lambda`

Creates an anonymous function and captures the current environment.

### 4.5 `do`

Evaluates expressions in order and returns the last result.

### 4.6 `load`

Loads another Calc file.

```calc
(load "collections/list")
(load "math/stats" :as util)
```

Rules:

- `load` accepts a string path.
- `:as` may be used to load into a namespace wrapper.
- Cyclic loads must fail with a runtime error.
- The same file should not be loaded twice in one execution.

## 5. Namespaces and Lookup

### 5.1 Lookup order

For unqualified names, lookup prefers:

1. Local lexical bindings in the current environment
2. Built-in literals and built-in functions
3. Lexically scoped environment bindings in the current chain
4. Variables in the current namespace chain
5. Functions in the current namespace chain

### 5.2 Qualified names

Qualified names like `crypto.twice` resolve directly in the named namespace.

### 5.3 Local names

Names beginning with `_` are treated as local to their namespace.
They are not intended to be resolved from other namespaces.

## 6. Builtins

Builtins are registered functions available without loading additional files.

The current baseline includes, at minimum:

- Arithmetic and comparison: `+`, `-`, `*`, `/`, `<`, `<=`, `>`, `>=`, `==`, `!=`
- Utility: `print`, `list`, `concat`, `length`
- Higher-order: `map`, `reduce`, `fold`, `select`
- Collections: `hash`, `get`, `set`, `entries`, `keys`, `values`, `has?`, `dig`, `hash-from-pairs`
- List helpers: `cons`, `append`, `concat-list`, `nth`, `first`, `rest`
- JSON: `parse-json`, `stringify-json`
- Time: `current-time`, `parse-time`, `format-time`, `next-month`, `prev-month`, `beggining-of-month`, `end-of-month`

## 7. Data Types

### 7.1 Numbers

- Numbers are represented as `BigDecimal`.
- Integer-like outputs may be formatted without a decimal point.

### 7.2 Lists

- Lists are ordered collections.
- List helpers should preserve order.

### 7.3 Hashes

- Hash keys are string keys internally.
- Keywords such as `:name` are used at the language level.

### 7.4 Lambdas

- Lambdas capture the environment at definition time.
- Parameter count must match call arity.

## 8. REPL and File Execution

### 8.1 REPL

- The REPL supports multiline input.
- It prints the last non-nil result of an input block.
- `:help` and `:ast` are debug commands.
- Tab completion should include special forms, builtins, literals, and currently reachable user-defined symbols.

### 8.2 File execution

- `bin/calc path/to/program.calc` executes a file.
- `--print-last-result` prints the final result after file execution.

## 9. Error Handling

Calc distinguishes at least these error classes:

- syntax errors
- name errors
- runtime errors

Common runtime failures include division by zero, unknown functions, and invalid load paths.
- Arithmetic operators expect numeric values. If a `nil` or non-numeric value reaches `+`, `-`, `*`, or `/`, the runtime should raise an error instead of coercing it silently.

Errors encountered in file mode are reported using the path:line:col format.

## 10. Testing Guidance

When writing Calc programs for tests:

- Prefer explicit `load` statements for dependent modules.
- Use `stdlib/test/` for stdlib regression tests.
- Use `modules/test/` for user module tests.
- Keep sample programs in `samples/` and sample verification wrappers in `samples/test/`.
