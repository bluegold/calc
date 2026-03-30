# Bytecode-Based Executer Migration Proposal

## Goal

現行の AST 直接評価型 `Executer` を、段階的に bytecode + VM 実行へ移行できるかを検討する。

このドキュメントは「即時置き換え」ではなく、以下を整理するための設計メモ:

- 期待できる効果
- 既存仕様との整合ポイント
- 段階的移行の進め方
- リスクと回避策

## Current State (as-is)

現行 `Executer` は tree-walk evaluator:

- パーサが AST (`NumberNode`, `SymbolNode`, `ListNode` など) を生成
- `Executer#evaluate` がノードを再帰評価
- special form は `executer/special_forms.rb` で個別実装
- クロージャは `LambdaValue(params, body, environment, namespace)` で保持
- `load` / namespace / 補完などは `Executer` の責務として実装済み

## Why Bytecode

想定メリット:

- AST ノード分岐を実行時に毎回行わず、命令列実行に寄せられる
- 制御構文 (`if`, `and`, `or`, `cond`) の分岐をジャンプ命令へ明示化できる
- 将来的な最適化（定数畳み込み、peephole、命令キャッシュ）を入れやすい
- デバッグ機能として逆アセンブル表示を提供しやすい

想定デメリット:

- 実装レイヤが増える（Parser / Compiler / VM）
- 既存エラー文言と位置情報の互換維持が難しくなる
- `load`・namespace・closure の相互作用テストが増える

## Non-Goals

初期段階では次を対象外とする:

- JIT コンパイル
- 命令最適化の本格導入
- 並列実行

## Semantic Compatibility Requirements

移行後も、以下の既存仕様を維持する必要がある:

- `if` は 3 引数必須 (`condition`, `then`, `else`)
- `and` は最初の falsey 値を返し、全 truthy の場合は最後の値を返す
- `or` は最初の truthy 値を返し、なければ `false`
- `cond` は `else` が最後のみ有効
- 真偽値規則は `false` と `nil` のみ falsey
- lexical scope が namespace 解決より優先
- `_` 始まりの namespace local 可視性
- `load` の循環検出と一度きりロード
- 既存のエラー分類 (`SyntaxError`, `NameError`, `RuntimeError`)

## Proposed Architecture

### 1. Compiler

AST を bytecode へ変換する。

責務:

- ノードごとの命令列生成
- 分岐ジャンプの backpatch
- ラムダ本体を別 `CodeObject` としてコンパイル
- 命令に line/column を付与（エラー文脈用）

### 2. CodeObject / Instruction

- `Instruction(op, operand, line, column)`
- `CodeObject(instructions, name)`

### 3. Virtual Machine (VM)

`Executer` の内部実行器として導入。

責務:

- スタック実行
- `load` / `store` / `call` / jump 系命令
- environment と namespace の現在状態管理
- 既存エラーへのマッピング

### 4. Lambda Runtime Value

現行互換を維持するため、当面は下記のどちらか:

- A. `LambdaValue` の body を AST から CodeObject へ置換
- B. `LambdaValue` に `ast_body` と `code_body` を併存（移行期間向け）

推奨は B（段階移行しやすいため）。

## Suggested Bytecode (Minimum Set)

- `push_const`
- `push_keyword`
- `load`
- `load_fn`
- `store`
- `store_fn`
- `make_closure`
- `call`
- `pop`
- `dup`
- `jump`
- `jump_false`
- `jump_true`
- `enter_ns`
- `leave_ns`
- `load_file`

## Stack Machine Conventions

Phase 1 ではスタックマシン前提を以下で固定する。

### Evaluation Order

- 式は左から右に評価する
- 関数呼び出しでは `callable` を先に積み、その後に `arg1..argN` を積む
- `call N` は `[callable, arg1, ... argN]` を消費し、`result` を 1 つ push する

### Instruction Stack Effects

- `push_const x`: `[] -> [x]`
- `push_keyword k`: `[] -> [":k"]`
- `load name`: `[] -> [value]`
- `load_fn name`: `[] -> [callable]`
- `store name`: `[value] -> [value]`
- `store_fn name`: `[closure] -> [defined-function-label]`
- `make_closure meta`: `[] -> [closure]`
- `call n`: `[callable, arg1, ... argN] -> [result]`
- `pop`: `[x] -> []`
- `dup`: `[x] -> [x, x]`
- `jump target`: no stack effect
- `jump_false target`: `[cond] -> []`
- `jump_true target`: `[cond] -> []`
- `enter_ns name`: no stack effect
- `leave_ns`: no stack effect
- `load_file meta`: `[] -> [result-or-nil]`

## Phased Migration Plan

### Phase 0: Documentation and Spec Lock

- このドキュメントをベースに移行条件を明確化
- `if` / `and` / `or` / `cond` の仕様をテストで固定

### Phase 1: Compiler + Bytecode Data Structures (No Runtime Switch)

- `Compiler` と `Bytecode` を追加
- 逆アセンブル表示を可能にする
- 実行は従来 `evaluate` のまま

### Phase 2: VM for a Safe Subset

- number/string/symbol/call と算術組み込みのみ VM 実行
- feature flag で tree-walk と切替可能にする
- 差分テストを追加（同一入力で同じ結果か）

### Phase 3: Special Forms and Namespace/Load

- `if`/`and`/`or`/`cond`/`define`/`lambda`/`do` を VM 化
- `namespace` と `load` を VM 化
- 既存 integration test を完全通過

### Phase 4: Default Switch

- 既定を VM に変更
- tree-walk を暫定 fallback として一定期間残す
- 十分に安定後、旧実装を段階削除

## Phase 0 Decisions (Locked)

2026-03-30 時点で、Phase 0 の前提を以下に固定する。

1. Lambda 移行方式
- Option B を採用する。
- `LambdaValue` は移行期間中 `ast_body` と `code_body` の併存を許容し、段階移行しやすさを優先する。

2. エラー互換判定
- 「実用一致」を採用する。
- 例外型一致 + 主要文言一致 + 位置情報付与有無の一致を合格基準とする。

3. Feature Flag
- 環境変数方式を採用する。
- `CALC_EXECUTER_MODE=tree|vm` を想定し、既定値は `tree` とする。

4. CI 方針
- tree/vm の両モードを CI で実行する前提を採用する。
- ただし VM 本実装前の段階では、VM ジョブを許容失敗または段階的必須化として運用する。

5. 分岐命令規約
- `jump_false` / `jump_true` は条件値を pop して判定する仕様で固定する。

6. call 規約
- 評価順は左から右。
- スタック規約は `[callable, arg1, arg2, ... argN]` を積み、`call N` はこれらを消費して `result` を push する。

7. Phase 0 完了基準
- 「厳格」を採用する。
- ドキュメント確定 + 互換テスト固定 + 既存テスト通過を完了条件とする。

## Deferred Design Topic

### 遅延評価 (lazy evaluation)

現時点では非目標のため実装対象に含めないが、将来的な拡張のために以下を保留事項として記録する。

- `call` 規約にサンク（thunk）を導入するか
- special form 以外への遅延導入範囲
- eager/lazy 混在時のエラー位置情報の扱い

Phase 0 完了には不要だが、Phase 2 以降で評価モデルを広げる際の検討項目とする。

## Risk Register

1. Short-circuit semantics drift
- Risk: `and` / `or` が真偽値化されて値を失う
- Mitigation: 専用回帰テストを先行追加

2. Error message drift
- Risk: ファイル位置や "while evaluating ..." 文言が崩れる
- Mitigation: instruction に line/column を保持し、既存 formatter を再利用

3. Namespace visibility regression
- Risk: `_` ローカル可視性が変わる
- Mitigation: `NamespaceRegistry` の既存テストを必須通過条件にする

4. Load lifecycle regression
- Risk: 循環検知/二重ロード抑止の挙動差
- Mitigation: `executer_loader_test` を移行のゲートに設定

## Test Strategy

- 既存 unit/integration をそのまま回す
- 追加するべきテスト:
  - compiler 出力のスナップショット（最小命令列）
  - VM と tree-walk の結果一致テスト（代表プログラム）
  - エラー文言一致テスト（位置情報含む）
- Phase 0 時点では `test/phase0_semantic_lock_test.rb` を追加し、`if` / `and` / `or` / `cond` の互換条件を固定する

## Rollback Plan

- feature flag で tree-walk 実行へ戻せる状態を維持
- VM 既定化後もしばらく fallback を残す

## Status

- 検討段階（実運用切り替えは未着手）
- Phase 0 は完了。設計前提と互換条件をドキュメントおよび回帰テストで固定した
- Phase 2 は完了。`CALC_EXECUTER_MODE=vm` で safe subset を VM 実行できる
- Phase 3 は完了。special form（`if`/`and`/`or`/`cond`/`define`/`lambda`/`do`）と `namespace` / `load` を VM 実行できる
- 現状は `CALC_EXECUTER_MODE=vm` で全テストが通るが、既定値はまだ `tree` のまま維持している
- 既存 `Executer` を主系として維持
- bytecode 関連の追加ファイルは「試作」扱いで、採用可否は本ドキュメントのフェーズ合意後に判断
