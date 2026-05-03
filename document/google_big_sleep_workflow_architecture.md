# Big Sleep-Style Framework Với Codex, CodeQL, Python Sandbox Và GDB

Tài liệu này là bản rút gọn để một session Codex có thể đọc nhanh và xây framework từ đầu. Mục tiêu là mô phỏng workflow kiểu Google Big Sleep / Project Naptime theo hướng phòng thủ, chạy trên code local hoặc code đã được ủy quyền.

Phần `report` được tạm bỏ qua. Flow kết thúc ở mức: có hoặc không có finding đã kiểm chứng, kèm evidence artifact tối thiểu.

## 1. Kiến Trúc Mục Tiêu

```text
Seed / Diff / Crash / Advisory
  -> Codex Agent
      -> Hypothesis Manager
      -> CodeQL Code Browser
      -> Python Sandbox
      -> Build / Test Harness
      -> GDB Debugger Runner
      -> Runtime Oracle
      -> Verifier
      -> State Store
  -> Verified Evidence Artifact
```

Vai trò chính:

| Thành phần | Tool chủ đạo | Vai trò |
|---|---|---|
| LLM agent | Codex Agent | Điều phối, đọc kết quả tool, lập giả thuyết, chọn thí nghiệm tiếp theo |
| Code browser | CodeQL | Tìm symbol, reference, call graph, dataflow, variant pattern |
| Testcase generator | Python sandbox | Sinh input/testcase local, tính toán format/offset/constraint |
| Debugger | GDB | Chạy target, lấy backtrace, breakpoint, inspect biến |
| Runtime oracle | ASan/UBSan/assertion/test failure | Bằng chứng deterministic |
| Verifier | custom verifier module + clean rerun | Chạy lại testcase, xác nhận finding |
| State store | JSONL hoặc SQLite | Lưu hypothesis, experiment, observation |

Nguyên tắc:

```text
Codex suy luận và điều phối.
Tool tạo bằng chứng.
Verifier mới được quyền xác nhận.
Không có reproduction thì không gọi là finding.
```

## 2. Flow Rút Gọn

```text
1. Nhận seed
2. Chuẩn hóa seed
3. Tạo giả thuyết
4. Duyệt code bằng CodeQL
5. Thiết kế thí nghiệm
6. Sinh testcase bằng Python sandbox
7. Build/chạy target
8. Debug bằng GDB nếu có crash/hang/assertion
9. Quan sát bằng runtime oracle
10. Sửa giả thuyết hoặc kiểm chứng
11. Lưu verified evidence artifact
```

## 3. Các Module Cần Xây

### 3.1 Codex Agent

Codex là bộ não điều phối, không phải verifier.

Codex phải làm:

- Đọc seed/diff/crash/advisory.
- Tóm tắt thay đổi hoặc tín hiệu lỗi.
- Tạo nhiều giả thuyết có thể kiểm chứng.
- Gọi CodeQL để đọc code theo symbol/reference/dataflow.
- Gọi Python sandbox để tạo testcase.
- Gọi build/test/debug runner.
- Phân loại kết quả: `supported`, `disproven`, `bad_input`, `bad_environment`, `wrong_path`, `inconclusive`, `verified`.
- Dừng khi verifier xác nhận hoặc khi hết giả thuyết giá trị cao.

Codex không được:

- Tự tuyên bố vulnerability nếu verifier chưa pass.
- Phóng đại impact nếu chỉ có assertion/debug-only crash.
- Chạy ngoài scope local/authorized.

### 3.2 Seed Normalizer

Input có thể là:

```text
git diff
git commit
crash log
sanitizer output
security advisory
fuzzing finding
bug class cần variant analysis
```

Tool đề xuất:

| Tool | Vai trò |
|---|---|
| `git show` | Lấy commit message và diff |
| `git diff --function-context` | Lấy diff có context function |
| `gh` CLI | Lấy PR/issue nếu code ở GitHub |
| `osv-scanner` | Lấy seed từ dependency advisory |
| custom `seed_normalizer.py` | Chuyển mọi seed về một schema thống nhất |

Schema tối thiểu:

```yaml
seed:
  id:
  type: diff | commit | crash | advisory | fuzzing
  summary:
  files:
  symbols:
  suspected_bug_classes:
  scope:
```

### 3.3 Hypothesis Manager

Mỗi giả thuyết phải có cách kiểm chứng hoặc bác bỏ.

Schema:

```yaml
hypothesis:
  id:
  bug_class:
  affected_component:
  suspected_invariant:
  attacker_controlled_input:
  code_path:
  expected_signal:
  experiment_plan:
  falsify_if:
  status: new | testing | supported | disproven | inconclusive | verified
```

Bug class nên ưu tiên:

- Bounds/length mismatch.
- Sentinel value bị xử lý như giá trị bình thường.
- Signed/unsigned conversion.
- Integer overflow/underflow.
- Null/state confusion.
- Use-after-free/lifetime bug.
- Incomplete patch variant.
- Parser state machine confusion.
- Access control/business logic chỉ trong scope local.

### 3.4 CodeQL Code Browser

CodeQL là code browser/ngữ nghĩa chính của framework. Nó không chỉ grep text, mà tạo database để query symbol, reference, call graph và dataflow.

Lệnh cơ bản:

```bash
codeql database create codeql-db --language=<language> --source-root .
codeql query run query.ql --database=codeql-db --output=result.bqrs
codeql bqrs decode result.bqrs --format=json --output=result.json
```

Wrapper nên xây:

```yaml
code_browser:
  action: symbol_search | references | callers | callees | dataflow | variant_pattern | file_slice
  symbol:
  file:
  line:
  pattern:
  query:
```

Các capability cần có:

- Tìm định nghĩa symbol.
- Tìm nơi symbol/field/function được dùng.
- Tìm caller/callee.
- Tìm đường dataflow từ input đến sink.
- Tìm pattern tương tự patch/bug seed.
- Trả về file/line/snippet đủ ngắn cho Codex đọc.

Tool phụ mạnh nên dùng cùng CodeQL:

| Tool | Khi dùng |
|---|---|
| `rg` | Tìm text nhanh, fallback khi CodeQL quá nặng |
| `git grep` | Tìm trong tracked files |
| `ctags` | Jump-to-definition nhẹ |
| `clangd` | C/C++ type/reference chính xác |
| `tree-sitter` | Tự viết AST extractor nhỏ |
| Semgrep | Pattern matching nhanh cho rule tự viết |
| Joern | CPG/dataflow mạnh cho C/C++/JVM khi CodeQL chưa đủ |

### 3.5 Python Sandbox

Python sandbox dùng để sinh testcase và xử lý dữ liệu. Nó không phải nơi viết exploit chain.

Nhiệm vụ:

- Tạo input có cấu trúc: JSON, XML, SQL, binary, config, HTTP fixture.
- Tính endian, checksum, length field, offset, boundary value.
- Tạo corpus nhỏ cho fuzzing.
- Rút gọn testcase sau khi có crash.

Wrapper nên xây:

```yaml
python_sandbox:
  action: generate_input | mutate_input | minimize_input | parse_output
  hypothesis_id:
  format:
  constraints:
  input_artifact:
  timeout:
```

Tool phụ mạnh:

| Tool | Khi dùng |
|---|---|
| Hypothesis | Property-based testing cho Python API/parser |
| Grammarinator | Sinh input theo grammar |
| Dharma | Grammar fuzzing nhẹ |
| custom reducer | Minimize testcase theo oracle |

### 3.6 Build / Test Harness

Build/test harness phải deterministic và script được.

Wrapper nên xây:

```yaml
build_test:
  action: configure | build | test | run_target
  profile: debug | asan | ubsan | release
  command:
  input_artifact:
  timeout:
  env:
```

Tool đề xuất:

| Tool | Khi dùng |
|---|---|
| project-native test runner | Mặc định: pytest, npm test, go test, cargo test, ctest |
| Docker/Podman | Cô lập môi trường |
| Nix/devenv | Reproducible build |
| ASan | C/C++ memory bug |
| UBSan | Undefined behavior |
| MSan | Uninitialized memory |
| TSan | Data race |
| Valgrind | Khi không build được sanitizer |

### 3.7 GDB Debugger Runner

GDB là debugger chính cho native target. Dùng batch mode để Codex có thể gọi lặp lại.

Wrapper nên xây:

```yaml
gdb_run:
  command:
  input_artifact:
  breakpoint:
  watchpoint:
  expressions:
  timeout:
  capture:
    stdout: true
    stderr: true
    backtrace: true
    registers: false
```

Ví dụ command dạng batch:

```bash
gdb --batch \
  -ex "run < testcase.bin" \
  -ex "bt" \
  -ex "info locals" \
  --args ./target
```

Tool phụ mạnh:

| Tool | Khi dùng |
|---|---|
| `lldb` | Nếu target build bằng LLVM hoặc môi trường macOS |
| `rr` | Bug nondeterministic, cần record/replay |
| `strace` | Quan sát syscall/file/network local |
| `perf` | Hang hoặc performance DoS |
| core dump parser | Postmortem crash analysis |

### 3.8 Runtime Oracle

Oracle là nguồn sự thật, không phải Codex.

Oracle mạnh:

```text
ASan report
UBSan report
debug assertion
SIGSEGV / SIGABRT
non-zero exit code có ý nghĩa
unit test failure
property test failure
differential test mismatch
hang/timeout có kiểm soát
```

Observation schema:

```yaml
observation:
  experiment_id:
  command:
  exit_code:
  signal:
  timeout:
  stdout_excerpt:
  stderr_excerpt:
  sanitizer:
    type:
    summary:
    stack:
  gdb:
    backtrace:
    frame:
    locals:
  classification:
```

### 3.9 Custom Verifier

Verifier là module tự chế, không phải tool public có sẵn. Nhiệm vụ của nó là chạy lại testcase từ đầu theo cách deterministic. Đây là cổng duy nhất chuyển finding sang `verified`.

Tên đề xuất có thể là `verify_repro.py`, nhưng đây chỉ là tên module tự xây. Nếu framework viết bằng ngôn ngữ khác, có thể đổi thành `verifier.ts`, `verifier.go`, `verify_repro.sh` hoặc một job CI.

Interface nên có:

```yaml
verify_repro:
  hypothesis_id:
  clean_checkout: true
  build_profile:
  command:
  input_artifact:
  expected_signal:
  expected_stack_contains:
  timeout:
```

Verifier pass khi:

- Build/run sạch thành công.
- Testcase reproduce.
- Signal khớp expected signal.
- Stack hoặc assertion khớp vùng code nghi ngờ.
- Không phụ thuộc trạng thái ngẫu nhiên.

Verifier fail khi:

- Không reproduce.
- Crash do harness/config sai.
- Chỉ có suy luận nhưng không có runtime evidence.
- Input nằm ngoài scope.

### 3.10 State Store

Không cần phức tạp ở bản đầu. Dùng JSONL là đủ.

Artifacts nên lưu:

```text
artifacts/
  seeds/
  hypotheses.jsonl
  experiments.jsonl
  observations.jsonl
  testcases/
  gdb/
  sanitizer/
  verified/
```

Nếu chạy nhiều phiên, dùng SQLite:

```sql
hypotheses(id, seed_id, bug_class, status, created_at)
experiments(id, hypothesis_id, command, input_artifact, status)
observations(id, experiment_id, signal, summary, artifact_path)
verified_findings(id, hypothesis_id, evidence_path)
```

## 4. End-To-End Algorithm

```text
for seed in seeds:
  normalized_seed = seed_normalizer(seed)

  hypotheses = Codex.generate_hypotheses(normalized_seed)

  for hypothesis in hypotheses:
    code_context = CodeQL.query(hypothesis)
    experiment = Codex.design_experiment(hypothesis, code_context)

    testcase = PythonSandbox.generate_input(experiment)
    run_result = BuildTestHarness.run(testcase)

    if run_result.has_crash_or_signal:
      debug_result = GDB.run(testcase)
      observation = RuntimeOracle.classify(run_result, debug_result)
    else:
      observation = RuntimeOracle.classify(run_result)

    Codex.update_hypothesis(hypothesis, observation)

    if observation.supports_hypothesis:
      verify_result = Verifier.rerun_clean(testcase, expected_signal)

      if verify_result.pass:
        save_verified_evidence(hypothesis, testcase, observation, verify_result)
        mark hypothesis as verified
        stop or continue based on policy

    if hypothesis is disproven:
      continue
```

## 5. Minimal MVP Cần Xây Trước

MVP nên nhỏ và chạy được:

```text
1. seed_normalizer.py
2. codeql_browser.py
3. python_sandbox.py
4. build_test_runner.py
5. gdb_runner.py
6. oracle_parser.py
7. custom_verifier.py hoặc verify_repro.py
8. state_store.py hoặc JSONL logger
```

Ưu tiên triển khai:

1. `seed_normalizer.py`: nhận `git diff` hoặc crash log.
2. `codeql_browser.py`: tạo DB, chạy query định nghĩa/reference/callers.
3. `build_test_runner.py`: chạy build/test với timeout.
4. `python_sandbox.py`: tạo testcase file.
5. `gdb_runner.py`: batch GDB lấy backtrace.
6. `oracle_parser.py`: parse ASan/assertion/GDB output.
7. custom verifier, ví dụ `verify_repro.py`: clean rerun và xác nhận signal.

## 6. Prompt Ngắn Cho Codex Session Khác

```text
Bạn là Codex Agent trong một framework vulnerability research phòng thủ kiểu Big Sleep.

Core tools:
- Code browser chính: CodeQL.
- Testcase generator: Python sandbox.
- Debugger chính: GDB.
- Runtime oracle: ASan/UBSan/assertions/test failures/GDB backtrace.
- Verifier: custom module/script chạy lại testcase từ môi trường sạch.

Quy tắc:
1. Chỉ làm việc trên code local hoặc code đã được ủy quyền.
2. Bắt đầu từ seed: diff, commit, crash, advisory hoặc bug class.
3. Tạo giả thuyết có thể kiểm chứng, không nói chung chung.
4. Dùng CodeQL để tìm definition, references, callers/callees, dataflow hoặc variant pattern.
5. Dùng Python sandbox để tạo testcase tối thiểu.
6. Chạy target qua build/test harness.
7. Nếu có crash/assertion/hang, dùng GDB để lấy backtrace và state.
8. Dùng runtime oracle để phân loại observation.
9. Nếu observation hỗ trợ giả thuyết, gọi verifier chạy lại sạch.
10. Chỉ đánh dấu verified khi verifier pass.
11. Tạm thời không viết report dài; chỉ lưu verified evidence artifact.

Output tối thiểu sau mỗi vòng:
- hypothesis_id
- code_context_used
- experiment_command
- testcase_artifact
- observation_summary
- hypothesis_status
- next_action
```

## 7. Tool Stack Khuyến Nghị

| Bước | Tool chủ đạo | Tool phụ mạnh |
|---|---|---|
| Seed | `git show`, `git diff` | `gh`, `osv-scanner` |
| Hypothesis | Codex Agent | Semgrep rules, custom invariant extractor |
| Code browsing | CodeQL | `rg`, `ctags`, `clangd`, Joern, tree-sitter |
| Testcase | Python sandbox | Hypothesis, Grammarinator, Dharma |
| Build/test | native build/test | Docker, Nix, ASan, UBSan, MSan, TSan |
| Debug | GDB | LLDB, rr, strace, perf |
| Oracle | ASan/UBSan/assertions | Valgrind, core dump parser, differential tests |
| Verify | custom verifier module, ví dụ `verify_repro.py` | Docker/Nix/local CI |
| State | JSONL | SQLite/Postgres |

## 8. Ghi Chú Quan Trọng

- CodeQL ở đây được dùng như code browser ngữ nghĩa. Vẫn nên có `rg` hoặc `git grep` để lấy snippet nhanh.
- `python_sandbox` và `gdb_run` nên là wrapper tự xây, không để Codex gọi shell tùy ý trong framework production.
- GDB phù hợp nhất với native Linux/C/C++. Với Rust/C++ vẫn dùng tốt; với Java/Python/Go cần debugger/test runner tương ứng.
- Sanitizer và verifier quan trọng hơn lời giải thích của LLM.
- Flow này phục vụ phòng thủ, variant analysis và local reproduction, không phục vụ khai thác hệ thống bên ngoài.

## 9. Nguồn Tham Khảo

- Google Project Zero, "Project Naptime: Evaluating Offensive Security Capabilities of Large Language Models", 2024-06-20: https://projectzero.google/2024/06/project-naptime.html
- Google Project Zero, "From Naptime to Big Sleep: Using Large Language Models To Catch Vulnerabilities In Real-World Code", 2024-10: https://projectzero.google/2024/10/from-naptime-to-big-sleep.html
