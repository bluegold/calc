# Repository Guidelines

## Project Structure & Module Organization
Use a standard Ruby layout for the S-expression calculator:

- `lib/` for parser, evaluator, and domain classes
- `bin/` for executable entry points
- `test/` for Minitest cases
- `README.md` for usage and expression syntax

Keep parsing and evaluation separate. For example, place tokenizing and AST logic in `lib/calc/parser.rb` and arithmetic evaluation in `lib/calc/evaluator.rb`.

## Build, Test, and Development Commands
Prefer `bundle exec` for all Ruby commands once a `Gemfile` exists.

- `bundle exec ruby -Itest test/parser_test.rb` - run a single test file
- `bundle exec ruby -Itest test/executer_test.rb` - run a single test file
- `bundle exec ruby bin/calc` - run the calculator CLI
- `bundle exec irb -I lib -r calc` - experiment interactively

## Coding Style & Naming Conventions
Follow standard Ruby style:

- Two-space indentation
- `snake_case` for methods and files, `CamelCase` for classes and modules
- Small methods with explicit names, especially around parsing and AST nodes

If `rubocop` is added, keep its configuration committed and run it before opening a PR.

## Testing Guidelines
Use Minitest for behavior coverage. Name files `test/*_test.rb` and keep methods focused on one behavior at a time.

- Test parser success and failure cases
- Test evaluator arithmetic and edge cases like division by zero
- Add regression tests for every bug fix

## Commit & Pull Request Guidelines
This repository has no Git history yet, so adopt a clear commit style from the start. Recommended format:

- `feat: add calculator parser`
- `fix: handle divide-by-zero`

Pull requests should include a short summary, test results, and examples of evaluated expressions when behavior changes.

## Security & Configuration Tips
Do not commit secrets, tokens, or machine-specific config. Use environment files such as `.env` only if the project later adds them, and document required variables in `README.md`.
