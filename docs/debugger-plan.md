# VM Debugger Implementation Plan

## Goal

Add a first debugger implementation for `calc` that supports **VM mode only** and is launched as a dedicated CLI command:

```sh
bin/calc debug <filename>
````

The first version does **not** need REPL-integrated debugging for ad hoc expressions.
Instead, debugging is performed against a compiled file/program with a dedicated debug prompt.

This keeps the first implementation simple and aligned with the VM architecture:

* one source file or program entrypoint
* one compiled code object / program
* deterministic source mapping
* explicit debugger lifecycle
* isolated UI via `DebugRunner`

---

## Non-Goals for First Version

These items are out of scope for the first implementation:

* Debugging in tree-walk mode
* REPL-native debugging of interactive input cells
* Editing source while paused
* Watch expressions with automatic re-evaluation
* Conditional breakpoints
* Remote debugging / DAP support
* Time-travel debugging
* Multi-file stepping UX beyond basic source mapping
* Inline source editing from the debugger prompt

These may be added later after the core VM debugger is stable.

---

## Entry Point and UX

### CLI entry point

Add a new CLI mode:

```sh
bin/calc debug <filename>
```

### First-version debugger prompt

Use a dedicated prompt, for example:

```text
(calcdb)
```

### Minimum supported commands

* `run`
* `continue`
* `step`
* `next`
* `finish`
* `break <function>`
* `break <line>`
* `delete <breakpoint-id>`
* `info break`
* `bt`
* `frame <index>`
* `locals`
* `print <expr>`
* `list`
* `quit`

### Suggested first subset if implementation is staged inside the debugger itself

If command support must be introduced incrementally, implement in this order:

1. `run`
2. `break <function>`
3. `continue`
4. `step`
5. `bt`
6. `locals`
7. `print <expr>`
8. `next`
9. `finish`
10. `break <line>`
11. `list`
12. breakpoint deletion and listing

---

## High-Level Design

### Main components

Introduce the following new concepts:

* `Calc::Cli::DebugRunner`
* `Calc::Debugger`
* `Calc::Breakpoint`
* `Calc::DebugFrame`
* `Calc::DebugPause` or equivalent pause result type
* VM/source metadata structures if not already present

### Responsibility split

#### `Calc::Cli::DebugRunner`

Responsible for:

* loading source file
* invoking parser/compiler
* creating VM + debugger
* running the debug prompt loop
* formatting debugger output
* dispatching debugger commands

#### `Calc::Debugger`

Responsible for:

* debugger state machine
* breakpoint registration and lookup
* stepping state
* pause/resume control
* current frame selection
* backtrace generation
* source listing support
* evaluating expressions in paused context

#### `Calc::Vm`

Responsible for:

* exposing execution events needed by the debugger
* reporting current instruction pointer / frame changes
* invoking debugger hooks before or after resumable instruction boundaries
* pausing execution safely

The VM should remain the execution engine.
The debugger should control execution, but should not become the VM.

---

## Core Requirement: VM Metadata for Debugging

The debugger can only be reliable if compiled code contains enough metadata.

### Required metadata

Compiled code objects should provide enough information to answer:

* which source file a given instruction belongs to
* which source line a given instruction belongs to
* which function/lambda a given instruction belongs to
* where a function starts and ends in instruction space
* which local variables exist in a frame
* how to render the current paused location

### Minimum metadata checklist

* source filename
* instruction offset -> source location mapping
* instruction offset -> function/lambda metadata mapping
* line -> instruction offset lookup for line breakpoints
* function name -> entrypoint mapping for function breakpoints
* frame-local variable metadata or equivalent access path

If line and function maps are emitted by the compiler, debugger implementation becomes much simpler.

---

## Debugger State Model

Debugger state should support at least:

* idle
* running
* paused
* terminated

Pause reasons should distinguish at least:

* breakpoint hit
* step
* next
* finish
* exception
* manual interrupt

### Internal execution controls

The debugger should support these execution intents:

* continue until breakpoint/termination
* stop at next stoppable instruction
* stop at next stoppable instruction in same frame depth (`next`)
* stop when current frame returns (`finish`)

---

## Breakpoint Model

### First-version breakpoint types

#### Function breakpoint

```text
break fib
```

Break when entering a function/lambda by name.

This is likely the easiest robust first breakpoint type if compiler metadata already knows function entrypoints.

#### Line breakpoint

```text
break 12
break path/to/file.calc:12
```

Break when execution reaches the specified line.

If the first implementation only supports the primary debug target file, plain line numbers are acceptable.
Support for explicit filenames can still be designed into the parser.

### Breakpoint requirements

Each breakpoint should have:

* numeric id
* kind (`function` or `line`)
* original user specification
* resolved target metadata
* enabled/disabled state

---

## Frame Model

A `DebugFrame` should contain enough information for `bt`, `frame`, `locals`, and `print`.

Suggested fields:

* frame index
* function name or label
* source file
* source line
* instruction pointer
* locals access handle or snapshot
* receiver/context if relevant
* argument names/values if available

### Frame navigation

Support:

* current frame selection
* `frame <index>`
* `bt` showing all frames with current source location

---

## Expression Evaluation While Paused

Support:

```text
print <expr>
```

This evaluates an expression in the current paused frame context.

### Constraints

The implementation must decide whether `print` is:

1. full evaluation with side effects, or
2. restricted inspection, or
3. full evaluation now, restricted mode later

Recommended first version:

* `print <expr>` performs normal evaluation in paused context
* document clearly that this may have side effects

This is the most practical initial choice.
A read-only expression mode can be introduced later if needed.

---

## Error and Exception Handling

The debugger should pause on uncaught runtime exceptions and show:

* exception class
* message
* paused source location if available
* backtrace

Optional for first version:

* a future `catch` command for breaking on all exceptions or named exceptions

Not required for phase 1, but the debugger architecture should leave room for it.

---

## Source Listing

The debugger should support:

```text
list
```

to show source lines around the current paused line.

### Minimum behavior

* display current file
* display a small window around the current line
* mark the current line clearly

Example:

```text
 10 | (define fib
 11 |   (lambda (n)
>12 |     (if (< n 2)
 13 |         n
 14 |         (+ (fib (- n 1)) (fib (- n 2))))))
```

---

## Recommended Implementation Phases

# Phase 0: Design and groundwork

## Objective

Clarify the debugger architecture and identify the VM/compiler metadata required.

## Deliverables

* debugger architecture agreed
* CLI entry point agreed
* VM event hook design agreed
* compiler metadata requirements documented

## TODO

* [x] Decide final CLI shape for `bin/calc debug <filename>`
* [ ] Decide debugger prompt format
* [ ] Decide debugger command syntax
* [ ] Decide whether debugger pause is represented by exception or result object
* [ ] Identify current VM resumable boundaries for stepping
* [ ] Identify where compiler can emit source mapping metadata
* [ ] Identify where function/lambda entry metadata can be emitted
* [ ] Identify how locals can be read from VM frames
* [x] Decide initial semantics of `print <expr>`

## Checkpoint

At the end of this phase, it should be possible to describe:

* how a breakpoint is resolved
* how the VM pauses
* how the debugger finds current file/line/function
* how frame locals are exposed

---

# Phase 1: Add CLI debug entry point and shell

## Objective

Create a dedicated debug command and interactive debug shell without full stepping support yet.

## Deliverables

* `bin/calc debug <filename>`
* `Calc::Cli::DebugRunner`
* debugger prompt loop
* command parser skeleton

## TODO

* [x] Add CLI dispatch for `debug`
* [x] Create `Calc::Cli::DebugRunner`
* [x] Load source file and compile debug target
* [ ] Instantiate VM + debugger objects
* [x] Implement debug prompt loop
* [x] Implement `quit`
* [x] Implement `run`
* [x] Add user-friendly startup banner/help summary
* [x] Decide behavior for missing filename / missing file / parse error

## Checkpoint

User can run:

```sh
bin/calc debug sample.calc
```

and interact with a debugger prompt even if only `run` and `quit` exist initially.

---

# Phase 2: Compiler and VM debug metadata

## Objective

Make compiled VM programs debuggable by attaching source/function metadata.

## Deliverables

* instruction -> source location mapping
* line -> instruction lookup
* function/lambda entry metadata
* enough frame metadata for backtraces

## TODO

* [x] Extend compiled code object to carry source filename
* [x] Extend compiled code object to carry instruction offset -> line mapping
* [x] Extend compiled code object to carry function/lambda metadata
* [x] Add line lookup structure for resolving line breakpoints
* [x] Add function name lookup structure for resolving function breakpoints
* [x] Ensure lambda/function entrypoints are distinguishable
* [ ] Expose current instruction offset from VM execution state
* [ ] Expose call stack/frame metadata from VM
* [ ] Expose locals/arguments access path for current frame

## Checkpoint

Given a paused VM state, the debugger can determine:

* current function
* current file
* current line
* current stack frames

---

# Phase 3: Pause/resume hooks in VM

## Objective

Allow the debugger to stop and resume execution safely.

## Deliverables

* VM hook integration
* debugger state transitions
* pause reasons
* resumable execution

## TODO

* [ ] Add debugger hook/callback entrypoints in VM dispatch loop
* [ ] Define stoppable execution points
* [ ] Trigger debugger check at each stoppable boundary
* [x] Support pausing on breakpoint hit
* [x] Support pausing on step
* [x] Support pausing on next
* [x] Support pausing on finish
* [ ] Preserve VM state across pause/resume
* [ ] Represent terminated program distinctly from paused program
* [ ] Ensure debugger hook overhead is acceptable when enabled

## Checkpoint

The VM can:

* run
* pause
* resume
* terminate

without losing execution state or corrupting the stack.

---

# Phase 4: Breakpoints

## Objective

Implement function and line breakpoints.

## Deliverables

* `break`
* `delete`
* `info break`
* breakpoint resolution and hit detection

## TODO

* [x] Create `Calc::Breakpoint` model
* [x] Implement `break <function>`
* [x] Implement `break <line>`
* [x] Resolve line breakpoints against current source metadata
* [x] Resolve function breakpoints against function entry metadata
* [x] Assign stable breakpoint ids
* [ ] Implement `delete <id>`
* [ ] Implement `info break`
* [ ] Handle duplicate breakpoint definitions sensibly
* [ ] Produce clear error messages for unknown line/function targets

## Checkpoint

User can set and inspect breakpoints before running the program.

---

# Phase 5: Stepping and stack inspection

## Objective

Implement the core debugger workflow.

## Deliverables

* `run`
* `continue`
* `step`
* `next`
* `finish`
* `bt`
* `frame`

## TODO

* [x] Implement `run`
* [x] Implement `continue`
* [x] Implement `step`
* [x] Implement `next`
* [x] Implement `finish`
* [ ] Track frame depth correctly for `next`
* [ ] Track return target correctly for `finish`
* [ ] Implement `bt`
* [ ] Implement selected-frame navigation with `frame <index>`
* [ ] Show current paused location after each stop
* [ ] Display pause reason in a human-readable way

## Checkpoint

A user can debug a recursive function using breakpoints and stepping commands.

---

# Phase 6: Locals, printing, and source listing

## Objective

Make the paused debugger state inspectable and useful.

## Deliverables

* `locals`
* `print <expr>`
* `list`

## TODO

* [ ] Implement `locals` for selected frame
* [ ] Define output formatting for locals
* [ ] Implement paused-context expression evaluation for `print <expr>`
* [ ] Decide whether `print` uses selected frame or current frame only
* [ ] Implement `list`
* [ ] Show current line marker in `list`
* [ ] Handle unavailable source file gracefully
* [ ] Handle evaluation errors in `print` gracefully without crashing debugger

## Checkpoint

A user can inspect the current frame, read nearby source, and evaluate expressions while paused.

---

# Phase 7: Exception pausing and polish

## Objective

Improve debugger usability and failure handling.

## Deliverables

* pause on uncaught exceptions
* better output formatting
* robust command errors
* debugger help

## TODO

* [ ] Pause on uncaught runtime exception
* [ ] Show exception class, message, and paused location
* [ ] Show debugger backtrace on exception
* [x] Add `help` command
* [x] Improve command parse error messages
* [x] Improve startup instructions
* [x] Ensure clean exit on EOF / Ctrl-C in debugger prompt
* [ ] Ensure clean exit on program termination
* [x] Ensure clean exit on program failure
* [ ] Review command naming consistency

## Checkpoint

The debugger is usable for normal programs and for debugging crashes.

---

## Suggested Command Semantics

### `run`

* starts execution from program entry
* if the program already ran, behavior should be explicitly defined
* recommended first behavior: reload/reinitialize program state and run from the beginning

### `continue`

* resumes from paused state
* invalid if program is not paused

### `step`

* stop at the next stoppable instruction, including inside called functions

### `next`

* stop at the next stoppable point in the current frame
* step over deeper calls

### `finish`

* continue until the current frame returns

### `bt`

* show stack frames from innermost to outermost

### `frame <index>`

* select a frame for inspection
* affects `locals` and `print`

### `locals`

* show local variables for selected frame

### `print <expr>`

* evaluate in selected frame context

### `list`

* show source around current selected frame location
* accept an optional line count and optional bytecode display mode

---

## Test Plan

The debugger should be tested at three levels:

* unit tests
* integration tests for debugger command behavior
* end-to-end CLI tests

---

# Unit Test Checklist

## Breakpoints

* [ ] function breakpoint resolves correctly
* [ ] line breakpoint resolves correctly
* [ ] invalid function breakpoint reports error
* [ ] invalid line breakpoint reports error
* [ ] duplicate breakpoints handled predictably
* [ ] breakpoint deletion removes only the targeted breakpoint
* [ ] disabled/deleted breakpoint no longer pauses execution

## Debugger state machine

* [ ] idle -> running transition works
* [ ] running -> paused transition works
* [ ] paused -> running via continue works
* [ ] paused -> terminated works
* [ ] invalid transitions are rejected clearly

## Stepping

* [ ] `step` stops at the next stoppable instruction
* [ ] `next` steps over nested call frames
* [ ] `finish` stops after current frame returns
* [ ] stepping at program end terminates cleanly

## Frames and locals

* [ ] backtrace order is correct
* [ ] selected frame changes correctly
* [ ] locals reflect the selected frame
* [ ] argument values appear correctly in frame data

## Source mapping

* [ ] instruction offsets map to expected source lines
* [ ] line breakpoint resolution matches actual stoppable instruction
* [ ] function entry mapping points to callable entrypoint

## Printing

* [ ] `print` evaluates expression in current frame
* [ ] `print` evaluates expression in selected frame
* [ ] `print` handles runtime errors cleanly
* [ ] `print` does not crash debugger on invalid expression

## Exceptions

* [ ] uncaught runtime exception pauses debugger
* [ ] exception pause includes message and location
* [ ] exception backtrace is available

---

# Integration Test Checklist

## CLI lifecycle

* [x] `bin/calc debug <filename>` starts debugger prompt
* [x] missing file reports clear error
* [x] parse error reports clear error
* [x] `quit` exits cleanly
* [x] EOF exits cleanly

## Breakpoint workflow

* [x] set breakpoint before `run`
* [x] `run` stops at breakpoint
* [x] `continue` resumes to next breakpoint or termination
* [ ] `info break` shows current breakpoints
* [ ] `delete` updates breakpoint list

## Stepping workflow

* [x] `step` enters called function
* [x] `next` stays in current frame
* [x] `finish` returns to caller
* [ ] `bt` reflects recursive calls correctly

## Inspection workflow

* [ ] `locals` shows expected bindings at breakpoint
* [ ] `print` returns expected value
* [ ] `list` shows current source region with marker
* [ ] `frame` changes the inspection target

## Exception workflow

* [ ] crash pauses debugger
* [ ] backtrace is visible after crash
* [ ] user can inspect locals after crash if frame exists

---

# End-to-End Scenario Tests

Create a small set of sample programs specifically for debugger tests.

## Suggested sample programs

### 1. Simple arithmetic flow

Used to verify:

* startup
* line breakpoints
* stepping
* termination

### 2. Recursive function (e.g. fibonacci/factorial)

Used to verify:

* function breakpoints
* recursive backtrace
* `next`
* `finish`

### 3. Nested function/lambda calls

Used to verify:

* stack frames
* locals
* selected frame behavior

### 4. Program with runtime exception

Used to verify:

* exception pause
* error reporting
* stack inspection after crash

### 5. Multi-line source file with several stoppable lines

Used to verify:

* line breakpoint resolution
* `list`
* current-line highlighting

---

## Open Questions

These should be resolved before or during implementation:

* Should `run` always reinitialize VM/program state?
* Should `print` allow side effects in the first version?
* Should line breakpoints resolve to the nearest stoppable instruction on the line, or require exact match?
* How should anonymous lambdas be named in stack traces?
* How should multi-file `load`ed code appear in source listings and backtraces?
* How should builtins appear in `step`/`next` behavior?
* Should stepping stop inside builtin calls at all, or always step over them?
* What is the exact stoppable boundary in the VM dispatch loop?

---

## Recommended Defaults

Unless implementation constraints force a different choice, use these defaults:

* `run` reinitializes program state
* `print` allows normal evaluation, including side effects
* line breakpoints resolve to the first stoppable instruction on that line
* anonymous lambdas get generated labels such as `<lambda@file:line>`
* builtins are stepped over by `next`
* builtins are not entered by `step` unless they execute Calc bytecode
* debugger starts with only the target file loaded for source listing purposes

---

## Acceptance Criteria for First Release

The first VM debugger release is complete when all of the following are true:

* `bin/calc debug <filename>` works
* user can set a breakpoint by function name
* user can set a breakpoint by line
* `run`, `continue`, `step`, `next`, and `finish` work
* debugger can show a backtrace
* debugger can show locals
* debugger can evaluate `print <expr>` while paused
* debugger can list nearby source
* uncaught exceptions pause execution and remain inspectable
* debugger exits cleanly on quit, EOF, and program termination
* automated tests cover the major command flows and pause conditions

---

## Recommended File/Module Additions

The exact file layout can vary, but a likely shape is:

* `lib/calc/cli/debug_runner.rb`
* `lib/calc/debugger.rb`
* `lib/calc/debug_frame.rb`
* `lib/calc/breakpoint.rb`
* `lib/calc/debug_pause.rb` or equivalent
* VM/compiler source metadata extensions in existing files
* CLI tests for `debug`
* VM-level debugger tests
* integration fixture programs under a debugger-specific fixtures directory

---

## Implementation Notes for Codex

When implementing, prefer these principles:

* keep debugger UI separate from VM execution logic
* keep `DebugRunner` thin
* put breakpoint and stepping logic in `Debugger`
* make metadata explicit rather than inferred at runtime when possible
* prefer stable and testable pause semantics over clever shortcuts
* make command parsing forgiving but execution-state validation strict
* ensure debugger errors do not crash the debugger session itself
