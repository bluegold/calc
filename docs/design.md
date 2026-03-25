# Design

## Main Components
The program should be organized around these core parts:

- `Parser`: converts source text into an abstract syntax tree
- `Executer`: evaluates the syntax tree in an environment
- `REPL`: reads input, invokes the parser and executer, and prints results

Additional useful components:

- `Lexer`: optional helper for turning text into tokens before parsing
- `Environment`: stores variable bindings and built-in functions
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

## Evaluation Flow
1. Read source text from stdin or a file
2. Strip a leading shebang line if present
3. Tokenize, ignoring `;` comments
4. Parse text into AST nodes
5. Evaluate each top-level form in a shared environment
6. Print the final result in REPL mode

## Notes
- Keep parsing and evaluation separate
- Special forms such as variable definition should be handled by the executer, not by the parser
- `if` should be implemented as a special form, not a regular function
- Use `minitest` for unit and integration tests
