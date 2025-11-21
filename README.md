# Satellite Thermal Control System
## Bare-Metal RISC-V RV32I Kernel Implementation

**Universidad de Ingeniería y Tecnología (UTEC)**
**Course:** Computing Systems (Sistemas de Cómputo)
**Project:** Final Project - Kernel Development
**Architecture:** RISC-V RV32I (Base ISA only)
**Date:** November 2025

---

## ⚡ QUICK START (Para Demostración)

**¿Tienes prisa? Ejecuta esto:**

```bash
# Script automático de demostración
./demo.sh
```

**O manualmente en 3 pasos:**

```bash
# 1. Generar datos de temperatura
python3 data/generate_temp_binary.py

# 2. Compilar
make clean && make all

# 3. Ejecutar (60 segundos)
timeout 60 make run-with-data
```

📖 **Guía detallada:** Ver [GUIA_EJECUCION.md](GUIA_EJECUCION.md) para instrucciones completas paso a paso

---

## 📋 Table of Contents

1. [Project Overview](#-project-overview)
2. [Key Features](#-key-features)
3. [System Architecture](#-system-architecture)
4. [Process Implementation (Assembly)](#-process-implementation-assembly)
5. [Temperature Data Management](#-temperature-data-management)
6. [Build & Run Instructions](#-build--run-instructions)
7. [Scheduler Scenarios](#-scheduler-scenarios)
8. [Technical Details](#-technical-details)
9. [Project Structure](#-project-structure)
10. [Performance Metrics](#-performance-metrics)

---

## 🎯 Project Overview

### Mission
Develop a **bare-metal kernel in Assembly RISC-V RV32I** to manage a satellite's thermal control system. The system implements three concurrent processes entirely in Assembly that monitor temperature, control cooling systems, and transmit telemetry data.

### Core Requirements (IS2021_ProyectoP1.pdf)

✅ **All processes implemented in Assembly RISC-V**
✅ **PC (Program Counter) capture** when temperature limit detected
✅ **External temperature data** loaded from file
✅ **Cooling deactivation at <55°C** (corrected from 60°C)
✅ **Four scheduler scenarios** with priority management
✅ **Complete bare-metal** implementation (no OS)

---

## 🚀 Key Features

### Hardware Design
- **Pure RV32I ISA** - No multiply/divide extension (M)
- **Manual div/mod** implementation in Assembly
- **CSR access** for PC capture (`mepc` register)
- **Memory-mapped UART** at 0x10000000

### Software Architecture
- **Assembly processes** with direct hardware access
- **External data loading** via QEMU device loader
- **Context switching** preserving all 32 registers
- **Performance tracking** with comprehensive metrics

### Process Characteristics
- **P1 (Assembly):** Temperature acquisition from memory
- **P2 (Assembly):** Cooling control with PC capture
- **P3 (Assembly):** UART telemetry display

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    RISC-V RV32I Hardware                    │
│  ┌────────────┐  ┌───────────┐  ┌──────────────────────┐  │
│  │ CPU 50MHz  │  │ 128MB RAM │  │ UART @0x10000000     │  │
│  │ (RV32I)    │  │           │  │ 115200 baud          │  │
│  └────────────┘  └───────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   Bare-Metal Kernel (C)                     │
│  ┌────────────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │ boot.S         │  │ scheduler.c │  │ metrics.c      │  │
│  │ (Entry Point)  │→ │ (4 modes)   │  │ (Tracking)     │  │
│  └────────────────┘  └─────────────┘  └────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              Processes (Assembly RISC-V RV32)               │
│  ┌──────────────────┐ ┌───────────────────┐ ┌───────────┐ │
│  │ process_p1.S     │ │ process_p2.S      │ │process_p3.S│
│  │ ───────────────  │ │ ────────────────  │ │───────────││
│  │ • Reads temp     │ │ • Monitors temp   │ │• Displays ││
│  │   from 0x8002000 │ │ • Activates >90°C │ │  telemetry││
│  │ • 5min sense +   │ │ • Deactivates     │ │• UART     ││
│  │   1min transmit  │ │   <55°C           │ │  protocol ││
│  │ • Captures PC    │ │ • Captures PC at  │ │• System   ││
│  │   at temp limit  │ │   state changes   │ │  status   ││
│  └──────────────────┘ └───────────────────┘ └───────────┘ │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              External Temperature Data (File)               │
│  data/temps_baseline.bin  →  Loaded at 0x80020000          │
│  100 bytes (1 byte per minute of LEO orbit)                │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Process Implementation (Assembly)

### Process P1: Temperature Acquisition (`process_p1.S`)

**Implemented in:** Assembly RISC-V RV32
**Data Source:** External file loaded at memory address `0x80020000`

```assembly
# Read temperature from memory (loaded by QEMU)
li t0, 0x80020000         # Base address
add t0, t0, s1            # + current_minute
lbu s2, 0(t0)             # Load temperature byte

# Capture PC when temp > 90°C
li t0, 90
ble s2, t0, no_limit
csrr t1, mepc             # Read Program Counter from CSR
la t0, p1_limit_pc
sw t1, 0(t0)              # Save captured PC
```

**Features:**
- Reads from QEMU-loaded memory region
- 6-minute cycle (5 sensing + 1 transmission)
- Manual modulo operation (`minute % 6`) without `rem` instruction
- PC capture using CSR `mepc` register

---

### Process P2: Cooling Control (`process_p2.S`)

**Implemented in:** Assembly RISC-V RV32
**Thresholds:** Activation >90°C, Deactivation <55°C

```assembly
check_activation:
  li t0, 90
  ble s0, t0, cooling_standby    # if temp <= 90, stay off

activate_cooling:
  csrr t1, mepc                  # Capture PC at activation
  la t0, p2_activation_pc
  sw t1, 0(t0)
  # ... activate cooling system ...

check_deactivation:
  li t0, 55
  bge s0, t0, cooling_active     # if temp >= 55, stay active

deactivate_cooling:
  csrr t1, mepc                  # Capture PC at deactivation
  la t0, p2_deactivation_pc
  sw t1, 0(t0)
  # ... deactivate cooling system ...
```

**Features:**
- Hysteresis window (90°C - 55°C) prevents oscillation
- PC captured at both activation and deactivation
- UART alerts showing captured PC in hexadecimal

---

### Process P3: UART Telemetry Display (`process_p3.S`)

**Implemented in:** Assembly RISC-V RV32
**Protocol:** Serial UART communication

```assembly
# Display system telemetry
lbu s1, 0(s0)    # current_temp
lbu s2, 1(s0)    # cooling_active
lbu s3, 2(s0)    # orbital_position

# Manual decimal printing (no div instruction)
li t1, 10
div_loop:
  blt t3, t1, div_done
  sub t3, t3, t1         # Manual division
  addi t4, t4, 1
  j div_loop
```

**Features:**
- Complete telemetry display
- Manual division for decimal printing
- Orbital zone detection (BRIGHT/DARK)
- System status monitoring

---

## 📊 Temperature Data Management

### External Data File System

**Problem:** Bare-metal has no filesystem
**Solution:** QEMU device loader

#### Data Files

```
data/
├── temps_baseline.txt  # Human-readable (100 values)
├── temps_baseline.bin  # Binary format (100 bytes)
└── generate_temp_binary.py  # Generator script
```

#### Temperature Profile (100-minute LEO orbit)

| Time (min) | Zone | Range | Anomalies |
|------------|------|-------|-----------|
| 0-42 | BRIGHT | 55-99°C | Min 7-9: 92-98°C ✅<br>Min 32-34: 91-99°C ✅ |
| 42-100 | DARK | 45-93°C | Min 90-99: 90-93°C ✅ |

**Anomaly Detection Points:** Minutes 7, 8, 9, 10, 11, 32, 33, 34, 35, 36, 37, 97, 98, 99

#### How It Works

1. **Generate binary data:**
   ```bash
   python3 data/generate_temp_binary.py
   ```
   Creates `temps_baseline.bin` with 100 bytes

2. **QEMU loads data into memory:**
   ```bash
   qemu-system-riscv32 -device loader,file=data/temps_baseline.bin,addr=0x80020000
   ```

3. **Process P1 reads from memory:**
   ```assembly
   li t0, 0x80020000
   add t0, t0, minute_offset
   lbu temp, 0(t0)
   ```

---

## 🔨 Build & Run Instructions

### Prerequisites
- `riscv64-unknown-elf-gcc` toolchain
- `qemu-system-riscv32` emulator
- Python 3 (for data generation)

### Quick Start

```bash
# 1. Generate temperature data
python3 data/generate_temp_binary.py

# 2. Build project
make clean
make all

# 3. Run with data (RECOMMENDED)
make run-with-data

# 4. Run with timeout (QEMU runs indefinitely)
timeout 10 make run-with-data

# Exit QEMU: Ctrl+A then X
```

### Build Targets

| Command | Description |
|---------|-------------|
| `make all` | Compile entire project |
| `make clean` | Remove build artifacts |
| `make run` | Run in QEMU (no external data) |
| `make run-with-data` | Run with temperature data loaded |
| `make debug` | Run in debug mode (GDB port 1234) |
| `make debug-with-data` | Debug with data loaded |

### Changing Test Data

Edit `data/generate_temp_binary.py` to modify temperature values, then:
```bash
python3 data/generate_temp_binary.py
make run-with-data
```

---

## 📅 Scheduler Scenarios

The system implements 4 scheduling modes as required by the project specification.

### Scenario 1: BASELINE (Round-Robin)

**File:** `src/kernel/scheduler.c:70`
**Order:** P1 → P2 → P3 (sequential)
**Characteristics:**
- Perfect fairness
- No priority
- No data loss
- O(1) scheduling

**Enable:**
```c
// src/kernel/main.c:32
scheduler_init(SCHED_BASELINE);
```

---

### Scenario 2: PRIORITY_1

**File:** `src/kernel/scheduler.c:102`
**Order:** P1 → P3 → P2 (fixed priority)
**Characteristics:**
- Non-consecutive P2 execution
- Potential data loss tracked
- Priority enforcement

**Enable:**
```c
scheduler_init(SCHED_PRIORITY_1);
```

---

### Scenario 3: PRIORITY_2

**File:** `src/kernel/scheduler.c:134`
**Order:** P2 → P1 → P3 (fixed priority)
**Characteristics:**
- Different priority order
- Cooling control prioritized
- Data loss detection

**Enable:**
```c
scheduler_init(SCHED_PRIORITY_2);
```

---

### Scenario 4: SYSCALLS (Context Switching)

**File:** `src/kernel/scheduler.c:166`
**Mechanism:** Full context save/restore
**Characteristics:**
- Preserves PC via `mepc` CSR
- Saves all 32 registers
- Automatic process switching

**Enable:**
```c
scheduler_init(SCHED_SYSCALLS);
```

---

## 🔧 Technical Details

### RISC-V ISA Configuration

```
ISA:        RV32I (Base Integer Instructions)
Extensions: Zicsr (CSR Access), Zifencei (Instruction Fence)
ABI:        ilp32
No M ext:   Manual div/mod implementation required
```

### Compiler Flags

```makefile
CFLAGS  = -march=rv32i_zicsr_zifencei -mabi=ilp32 -O2
          -ffreestanding -nostdlib -mcmodel=medany
ASFLAGS = -march=rv32i_zicsr_zifencei -mabi=ilp32
LDFLAGS = -nostdlib -nostartfiles -T linker.ld
          -Wl,--no-relax -lgcc
```

### Memory Layout

```
0x80000000  .text     (14.6 KB) - Code
0x80003900  .rodata   (4.0 KB)  - Read-only data (strings)
0x80004900  .data     (0.5 KB)  - Initialized data
0x80004D00  .bss      (0.6 KB)  - Uninitialized data
0x80005000  Stack P1  (4 KB)
0x80006000  Stack P2  (4 KB)
0x80007000  Stack P3  (4 KB)
0x80008000  Kernel Stack (64 KB)
0x80020000  Temp Data (100 bytes) - Loaded by QEMU
0x80020064  Free RAM  (127 MB)
```

### Manual Division/Modulo Implementation

Since RV32I lacks hardware div/mod (requires M extension):

**Modulo Example:**
```assembly
# Calculate: t1 = s1 % 6
mv t1, s1
li t2, 6
mod_loop:
  blt t1, t2, mod_done
  sub t1, t1, t2
  j mod_loop
mod_done:
  # t1 now contains remainder
```

**Division Example:**
```assembly
# Calculate: quotient=t4, remainder=t3 for t0/10
li t1, 10
mv t3, t0
li t4, 0
div_loop:
  blt t3, t1, div_done
  sub t3, t3, t1
  addi t4, t4, 1
  j div_loop
div_done:
```

### PC Capture Mechanism

```assembly
# When temperature limit detected
csrr t1, mepc           # Read Program Counter from machine exception PC
la t0, saved_pc_var     # Load address of storage variable
sw t1, 0(t0)            # Store captured PC

# Display via UART
la t0, saved_pc_var
lw a0, 0(t0)
call uart_print_hex     # Prints: "PC: 0x800015C4"
```

---

## 📁 Project Structure

```
scp/
├── src/
│   ├── kernel/
│   │   ├── boot.S                  # Entry point, stack init
│   │   ├── context_switch.S        # Save/restore 32 registers
│   │   ├── main.c                  # Kernel initialization
│   │   ├── scheduler.c             # 4 scheduling algorithms
│   │   ├── process_manager.c       # Process table management
│   │   └── metrics.c               # Performance tracking
│   │
│   ├── processes/
│   │   ├── process_p1.S            # ⭐ Temperature acquisition (Assembly)
│   │   ├── process_p2.S            # ⭐ Cooling control (Assembly)
│   │   ├── process_p3.S            # ⭐ UART display (Assembly)
│   │   └── backup_c/               # Original C versions (backup)
│   │
│   ├── drivers/
│   │   └── uart.c                  # UART driver + uart_print_hex
│   │
│   └── lib/
│       └── satellite.c             # Satellite state management
│
├── include/
│   ├── process.h                   # Process definitions
│   ├── scheduler.h                 # Scheduler modes
│   ├── satellite.h                 # Thresholds (55°C deactivation)
│   ├── uart.h                      # UART functions
│   └── types.h                     # Basic types
│
├── data/
│   ├── temps_baseline.txt          # Human-readable temps
│   ├── temps_baseline.bin          # Binary data for QEMU
│   └── generate_temp_binary.py     # Data generator
│
├── bin/
│   ├── satellite_os.elf            # Final executable
│   └── satellite_os.asm            # Disassembly
│
├── docs/
│   └── HARDWARE_SOFTWARE_TRADEOFFS.md
│
├── Makefile                        # Build system
├── linker.ld                       # Memory layout script
├── CLAUDE.md                       # Claude Code instructions
└── README.md                       # This file
```

---

## 📈 Performance Metrics

### Tracked Metrics

| Metric | Description |
|--------|-------------|
| Scheduler Cycles | Total execution cycles |
| Context Switches | Number of process switches |
| Process Executions | Per-process execution count |
| Temperature Readings | Sensor read operations |
| Temperature Anomalies | Detections >90°C |
| Cooling Activations | System activation events |
| Cooling Deactivations | System deactivation events |
| UART Bytes | Total bytes transmitted |
| UART Messages | Message count |
| Data Loss Events | Abrupt non-consecutive switches |

### View Metrics

Metrics are printed at the end of execution:
```bash
timeout 10 make run-with-data
```

Output example:
```
=== PERFORMANCE METRICS SUMMARY ===
Scheduler cycles:        100
Temperature anomalies:   14
Cooling activations:     3
Cooling deactivations:   3
UART bytes transmitted:  12500
```

---

## 🎓 Academic Compliance

### Requirements Checklist (IS2021_ProyectoP1.pdf)

- [x] **Processes in Assembly RISC-V** (Section 3)
- [x] **PC capture at temperature limit** (Section 3)
- [x] **External temperature files** (Section 4)
- [x] **Cooling thresholds**: >90°C on, <55°C off (Section 1)
- [x] **Four scheduler scenarios** (Section 3)
- [x] **Priority scheduler** (Section 3)
- [x] **100-minute LEO orbit** (Section 2)
- [x] **Temperature anomalies** (Section 2)
- [x] **UART protocol for P3** (Section 2)
- [x] **Performance metrics** (Section 4)

---

## 🔬 Testing

### Run All Scenarios

```bash
# Generate data
python3 data/generate_temp_binary.py

# Test each scenario
for scenario in BASELINE PRIORITY_1 PRIORITY_2 SYSCALLS; do
  # Edit src/kernel/main.c:32 to set scenario
  make clean && make all
  timeout 10 make run-with-data
done
```

### Expected Behavior

**BASELINE:**
- Sequential P1→P2→P3 execution
- Cooling activates at minutes 7-9, 32-37, 97-99
- Cooling deactivates when temp drops below 55°C
- PC captured and displayed when temp > 90°C

**PRIORITY modes:**
- Non-sequential execution order
- Data loss tracked for abrupt switches
- Different process priorities

**SYSCALLS:**
- Full context preservation
- PC saved/restored via mepc
- Resume from exact instruction

---

## 📚 References

- **Patterson & Hennessy** - Computer Organization and Design RISC-V Edition
- **RISC-V Spec** - Volume I: Unprivileged ISA
- **RISC-V Spec** - Volume II: Privileged Architecture
- **QEMU Documentation** - Device Loader
- **Project Specification** - IS2021_ProyectoP1.pdf

---

## 👥 Authors

**Universidad de Ingeniería y Tecnología (UTEC)**
Course: Computing Systems - IS2021
Instructor: Luz A. Adanaqué

---

## 📝 License

Academic project for educational purposes.

---

**Last Updated:** November 19, 2025
**Version:** 2.0 (Assembly Implementation)
