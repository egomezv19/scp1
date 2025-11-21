# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **bare-metal RISC-V RV32I kernel** for satellite thermal control system. It implements a custom bootloader, context switching, and process scheduler entirely in assembly and C, without any operating system.

**Key Characteristics:**
- **Architecture:** RISC-V RV32I with Zicsr and Zifencei extensions
- **Purpose:** Manage satellite thermal control with 3 concurrent processes
- **Size:** ~18KB code, ~30KB total memory footprint
- **No OS:** Completely bare-metal implementation

## Build Commands

### Basic Build
```bash
make clean          # Remove all build artifacts
make all            # Compile the entire project
make run            # Build and run in QEMU emulator
```

### Testing
```bash
# Run all scenarios
./tests/run_all_tests.sh

# Run specific scenario
./tests/test_scenario_baseline.sh      # Scenario 1: Round-robin
./tests/test_scenario_priority1.sh     # Scenario 2: P1→P3→P2
./tests/test_scenario_priority2.sh     # Scenario 3: P2→P1→P3
./tests/test_scenario_syscalls.sh      # Scenario 4: Context switching

# Quick test with timeout (QEMU runs indefinitely otherwise)
timeout 10 qemu-system-riscv32 -machine virt -nographic -bios none -kernel bin/satellite_os.elf
```

### Debug
```bash
make debug          # Run QEMU in debug mode (opens GDB port 1234)
```

### Exit QEMU
Press `Ctrl+A` then `X` to exit QEMU emulator.

## Architecture Overview

### Boot Sequence
```
_start (boot.S) → Initialize stack → Clear BSS → main() → uart_init() →
metrics_init() → satellite_init() → process_init() → scheduler_init() → scheduler_run()
```

### Key Components

1. **Bootloader** (`src/kernel/boot.S`)
   - Assembly entry point at `_start`
   - Disables interrupts, sets up stack pointer at `_stack_top`
   - Clears BSS section, jumps to `main()`

2. **Context Switching** (`src/kernel/context_switch.S`)
   - Saves/restores all 31 registers (x1-x31) and PC (mepc CSR)
   - Full context: 148 bytes per process
   - Performance: ~80 cycles per switch (40 save + 40 restore)

3. **Scheduler** (`src/kernel/scheduler.c`)
   - Four scheduling modes (see Scheduler Modes below)
   - Change mode by editing `src/kernel/main.c:32`

4. **Processes**
   - **P1** (`src/processes/process_p1.c`): Temperature acquisition (5 min sensing + 1 min transmission)
   - **P2** (`src/processes/process_p2.c`): Cooling control (activate >90°C, deactivate ≤60°C)
   - **P3** (`src/processes/process_p3.c`): UART display of system state

5. **Shared State** (`src/lib/satellite.c`)
   - Global `satellite_state_t` structure accessed by all processes
   - Single-word atomic access (safe on RV32I without locks)

### Memory Layout
```
0x80000000  Text/Code section (13.7 KB)
            Read-only data (.rodata) (4.0 KB) - temp data, strings
            Data (.data) (0.5 KB)
            BSS (.bss) (0.5 KB)
0x80004000  Stack P1 (4 KB)
0x80005000  Stack P2 (4 KB)
0x80006000  Stack P3 (4 KB)
0x80007000  Kernel Stack (64 KB)
0x80017000  Free RAM (127.9 MB)

Peripherals:
0x10000000  UART (memory-mapped I/O, 115200 baud)
```

## Scheduler Modes

The scheduler supports 4 different execution scenarios. To switch between them:

1. Edit `src/kernel/main.c` line 32
2. Change the parameter to `scheduler_init()`:
   - `SCHED_BASELINE` - Round-robin P1→P2→P3 (default)
   - `SCHED_PRIORITY_1` - Fixed order P1→P3→P2
   - `SCHED_PRIORITY_2` - Fixed order P2→P1→P3
   - `SCHED_SYSCALLS` - Context switching with PC preservation
3. Recompile: `make clean && make all`

**Key Differences:**
- **BASELINE**: Perfect fairness, no data loss, O(1) scheduling
- **PRIORITY modes**: Non-consecutive switches cause data loss (tracked in metrics)
- **SYSCALLS**: Full context save/restore using assembly routines

## Important Technical Details

### RISC-V ISA Configuration
- **ISA:** RV32I base (32-bit integer instructions only)
- **Extensions:**
  - `Zicsr` - Required for CSR access (mepc, mstatus)
  - `Zifencei` - Required for instruction fence
- **No hardware MUL/DIV:** Uses software implementations from libgcc
- **ABI:** ilp32 (int/long/pointer = 32-bit)

### Compiler Flags (from Makefile)
```makefile
CFLAGS = -march=rv32i_zicsr_zifencei -mabi=ilp32 -O2 -ffreestanding -nostdlib
LDFLAGS = -nostdlib -nostartfiles -T linker.ld -Wl,--no-relax -lgcc
```

**Critical:** Always use `-lgcc` for linking (provides `__udivsi3`, `__umodsi3` for division/modulo)

### Context Switch Assembly Interface

The assembly context switch routines in `src/kernel/context_switch.S` expect:
- `a0` register: pointer to PCB structure
- PCB layout matches `pcb_t` in `include/process.h`:
  - Offset 0: PC (mepc)
  - Offset 4-127: Registers x1-x31 (31 × 4 bytes)

**DO NOT** modify PCB structure without updating assembly code.

### UART Communication

```c
// UART base address
#define UART_BASE 0x10000000

// Functions
uart_init()          // Initialize UART peripheral
uart_putc(char)      // Send single character
uart_puts(char*)     // Send string
uart_send_temp(u8)   // Send temperature in format "TEMP:XXC\r\n"
```

## Code Modification Guidelines

### Adding a New Process

1. Create `src/processes/process_pN.c`
2. Add process state structure
3. Implement process logic function
4. Update `process_init()` in `src/kernel/process_manager.c`
5. Add process execution case in `scheduler.c:execute_process()`
6. Define new `PROCESS_PN` in `include/process.h`

### Modifying Scheduler

- Scheduler implementations start at `scheduler.c:70`
- Each mode has dedicated function: `schedule_baseline()`, `schedule_priority1()`, etc.
- Always call `metrics_inc_cycle()` at end of each scheduler cycle
- Use `metrics_record_abrupt_switch()` for non-consecutive process switches

### Working with Metrics

Metrics system tracks:
- Scheduler cycles and process switches
- Temperature readings and anomalies (>90°C)
- Cooling activations/deactivations
- UART bytes transmitted
- Data loss events (abrupt switches)

All metrics functions are in `src/kernel/metrics.c`:
```c
metrics_init()                           // Initialize at boot
metrics_inc_process_execution(pid)       // Track process execution
metrics_record_abrupt_switch(from, to)   // Record data loss event
metrics_print_summary()                  // Print summary report
```

### Memory Constraints

- Total available RAM: 128 MB
- Current usage: ~30 KB (0.02%)
- Process stacks: 4 KB each (95% unused in practice)
- **Safe to reduce stacks to 1 KB** if memory constrained
- No dynamic memory allocation (no heap, no malloc)

### Temperature Data

Temperature profile is defined in `src/processes/process_p1.c`:
- Array covers 100-minute LEO orbit simulation
- Minutes 0-41: BRIGHT zone (55-99°C)
- Minutes 42-99: DARK zone (45-93°C)
- Anomalies (>90°C) at minutes: 7-9, 32-34, 91-99

## Debugging Tips

### Common Issues

1. **"undefined reference to __udivsi3"**
   - Solution: Add `-lgcc` to linker flags

2. **Stuck in infinite loop / no output**
   - Check stack pointer initialization in `boot.S`
   - Verify UART base address is 0x10000000
   - Use `make debug` and connect GDB

3. **Context switch crashes**
   - Verify PCB structure alignment with assembly code
   - Check stack boundaries (stack overflow?)
   - Ensure mepc CSR is being saved/restored

4. **QEMU won't exit**
   - Use `timeout N qemu-system-riscv32 ...`
   - Or press `Ctrl+A` then `X`

### Verification Commands

```bash
# Check binary size
riscv64-unknown-elf-size bin/satellite_os.elf

# Expected output:
#    text    data     bss     dec     hex filename
#   13748    4096     562   18406    47e6 bin/satellite_os.elf

# View disassembly
less bin/satellite_os.asm

# Check stack usage (manual inspection)
riscv64-unknown-elf-objdump -h bin/satellite_os.elf
```

## Performance Characteristics

- **CPI (Cycles Per Instruction):** ~2.1 estimated
- **Context switch overhead:** ~80 cycles
- **Scheduler overhead:** 0.16% of total execution
- **UART latency:** 87 μs per byte at 115200 baud

## Related Documentation

- `README.md` - Complete project documentation with diagrams
- `docs/HARDWARE_SOFTWARE_TRADEOFFS.md` - Design decisions and trade-offs analysis
- `VERIFICATION_REPORT.md` - Test results and verification
- `linker.ld` - Memory layout linker script
