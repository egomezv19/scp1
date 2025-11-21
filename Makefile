# Makefile para proyecto RISC-V Satellite Control

# Toolchain RISC-V
PREFIX = riscv64-unknown-elf-
CC = $(PREFIX)gcc
AS = $(PREFIX)as
LD = $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

# Flags de compilación para RV32I con extensiones necesarias
# Zicsr: Control and Status Register instructions
# Zifencei: Instruction-Fetch Fence
CFLAGS = -march=rv32i_zicsr_zifencei -mabi=ilp32 -O2 -Wall -Wextra -ffreestanding -nostdlib -mcmodel=medany
ASFLAGS = -march=rv32i_zicsr_zifencei -mabi=ilp32
# Usar GCC como driver para linking (mejor práctica)
# -lgcc: enlazar contra libgcc para operaciones como división/módulo (RV32I no tiene HW div/mod)
LDFLAGS = -march=rv32i_zicsr_zifencei -mabi=ilp32 -nostdlib -nostartfiles -T linker.ld -Wl,--no-relax -lgcc

# Directorios
SRC_DIR = src
KERNEL_DIR = $(SRC_DIR)/kernel
PROC_DIR = $(SRC_DIR)/processes
DRIVER_DIR = $(SRC_DIR)/drivers
LIB_DIR = $(SRC_DIR)/lib
INC_DIR = include
BUILD_DIR = build
BIN_DIR = bin

# Archivos fuente
KERNEL_SRCS = $(wildcard $(KERNEL_DIR)/*.c) $(wildcard $(KERNEL_DIR)/*.S)
PROC_SRCS = $(wildcard $(PROC_DIR)/*.c) $(wildcard $(PROC_DIR)/*.S)
DRIVER_SRCS = $(wildcard $(DRIVER_DIR)/*.c)
LIB_SRCS = $(wildcard $(LIB_DIR)/*.c)

# Objetos
OBJS = $(KERNEL_SRCS:%.c=$(BUILD_DIR)/%.o) \
       $(KERNEL_SRCS:%.S=$(BUILD_DIR)/%.o) \
       $(PROC_SRCS:%.c=$(BUILD_DIR)/%.o) \
       $(PROC_SRCS:%.S=$(BUILD_DIR)/%.o) \
       $(DRIVER_SRCS:%.c=$(BUILD_DIR)/%.o) \
       $(LIB_SRCS:%.c=$(BUILD_DIR)/%.o)

# Target principal
TARGET = $(BIN_DIR)/satellite_os.elf
LINKER_SCRIPT = linker.ld

# Reglas
.PHONY: all clean run debug

all: $(TARGET)

$(TARGET): $(OBJS) $(LINKER_SCRIPT) | $(BIN_DIR)
	$(CC) -march=rv32i_zicsr_zifencei -mabi=ilp32 -nostdlib -nostartfiles -T linker.ld -Wl,--no-relax -o $@ $(filter %.o,$^) -lgcc
	$(OBJDUMP) -D $@ > $(BIN_DIR)/satellite_os.asm

# Compilar archivos C
$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -I$(INC_DIR) -c $< -o $@

# Compilar archivos Assembly
$(BUILD_DIR)/%.o: %.S | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(AS) $(ASFLAGS) -I$(INC_DIR) -c $< -o $@

# Crear directorios
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Ejecutar en QEMU (sin datos externos)
run: $(TARGET)
	qemu-system-riscv32 -machine virt -nographic -bios none -kernel $<

# Ejecutar en QEMU con datos de temperatura cargados desde archivo
run-with-data: $(TARGET)
	@echo "Loading temperature data from data/temps_baseline.bin to address 0x80020000"
	qemu-system-riscv32 -machine virt -nographic -bios none -kernel $< \
		-device loader,file=data/temps_baseline.bin,addr=0x80020000

# Debug
debug: $(TARGET)
	qemu-system-riscv32 -machine virt -nographic -bios none -kernel $< -s -S

# Debug with data
debug-with-data: $(TARGET)
	@echo "Loading temperature data from data/temps_baseline.bin to address 0x80020000"
	qemu-system-riscv32 -machine virt -nographic -bios none -kernel $< \
		-device loader,file=data/temps_baseline.bin,addr=0x80020000 -s -S

clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR)

# Ayuda
help:
	@echo "Targets disponibles:"
	@echo "  all             - Compilar el proyecto"
	@echo "  run             - Ejecutar en QEMU"
	@echo "  run-with-data   - Ejecutar en QEMU cargando datos de temperatura desde archivo"
	@echo "  debug           - Ejecutar en modo debug"
	@echo "  debug-with-data - Ejecutar en modo debug con datos de temperatura"
	@echo "  clean           - Limpiar archivos generados"
