# Design

## Main Components
The program should be organized around these core parts:

- `Parser`: converts source text into an abstract syntax tree
- `Executer`: evaluates the syntax tree in an environment
- `REPL`: reads input, invokes the parser and executer, and prints results

Additional useful components:

- `Lexer`: optional helper for turning text into tokens before parsing
- `Environment`: stores lexical bindings for variables and function parameters
- `NamespaceRegistry`: resolves namespace-scoped variables and functions across the current namespace chain
- `AST nodes`: represent numbers, symbols, calls, and special forms such as variable definition
- `Error types`: separate syntax, name, and runtime errors

## Syntax Tree Shape
Represent expressions as small Ruby objects or plain structs. A practical minimal tree is:

- `NumberNode(value)`
- `SymbolNode(name)`
- `ListNode(children)` for S-expressions

Numbers should normalize to `BigDecimal` as early as practical. This keeps arithmetic consistent and avoids mixing native integer and decimal behavior.

Comments beginning with `;` should be stripped during tokenization.

This keeps parsing simple and lets the executer decide whether a list is a function call or a special form such as `define` or `if`.

Namespaces should be treated as a runtime concern, not a parsing concern. The parser only needs to recognize the `namespace` special form as a list.

Namespace resolution should respect lexical scope first. `Environment` bindings for function parameters and local values must shadow namespace lookups. Functions and variables whose names start with `_` are local to their defining namespace and are not visible outside it.

Function values should be represented explicitly so the language can support higher-order functions. `lambda` should create a closure that captures the current lexical environment together with the current namespace at definition time. `define` for functions is syntactic sugar over `lambda`, so users can continue to write named functions while the runtime still treats them as first-class values.

Closures should evaluate their bodies eagerly. Delayed evaluation is not part of the initial design. Anonymous recursion is also out of scope for the first implementation. When a function value is printed for debugging or `:ast`, it should be rendered as structured AST-like data rather than as an opaque Ruby object.

## Evaluation Flow
1. Read source text from stdin or a file
2. Strip a leading shebang line if present
3. Tokenize, ignoring `;` comments
4. Parse text into AST nodes
5. Evaluate each top-level form in a shared lexical environment
6. Print the final result in REPL mode

## Notes
- Keep parsing and evaluation separate
- Special forms such as variable definition should be handled by the executer, not by the parser
- `if` should be implemented as a special form, not a regular function
- `namespace` should also be implemented as a special form, with resolution order of current namespace, parent namespaces, then `builtin`
- Qualified names such as `crypto.twice` should resolve directly through `NamespaceRegistry`
- Use `minitest` for unit and integration tests
