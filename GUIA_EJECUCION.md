# 🚀 GUÍA COMPLETA DE EJECUCIÓN DEL PROYECTO
## Cómo Compilar, Probar y Demostrar el Sistema

**Para:** Demostración ante la profesora y evaluación del proyecto
**Proyecto:** Sistema de Control Térmico de Satélite - RISC-V RV32I
**Versión:** 2.0 (Assembly Implementation)

---

## 📋 Tabla de Contenidos

1. [Verificación de Requisitos](#1-verificación-de-requisitos)
2. [Compilación del Proyecto](#2-compilación-del-proyecto)
3. [Ejecución de los 4 Escenarios](#3-ejecución-de-los-4-escenarios)
4. [Qué Mostrar a la Profesora](#4-qué-mostrar-a-la-profesora)
5. [Troubleshooting](#5-troubleshooting)
6. [Cambiar Datos de Temperatura](#6-cambiar-datos-de-temperatura)

---

## 1. Verificación de Requisitos

### Paso 1.1: Verificar Toolchain RISC-V

Abre una terminal en el directorio del proyecto y ejecuta:

```bash
riscv64-unknown-elf-gcc --version
```

**Salida esperada:**
```
riscv64-unknown-elf-gcc (GCC) 13.2.0
...
```

Si no está instalado, consulta la documentación de instalación del toolchain.

---

### Paso 1.2: Verificar QEMU

```bash
qemu-system-riscv32 --version
```

**Salida esperada:**
```
QEMU emulator version 8.x.x
...
```

---

### Paso 1.3: Verificar Python 3

```bash
python3 --version
```

**Salida esperada:**
```
Python 3.x.x
```

---

## 2. Compilación del Proyecto

### Paso 2.1: Navegar al Directorio del Proyecto

```bash
cd /home/mateoismael/SC/proyecto/scp
```

---

### Paso 2.2: Limpiar Compilaciones Anteriores

```bash
make clean
```

**Salida esperada:**
```
rm -rf build bin
```

---

### Paso 2.3: Generar Datos de Temperatura

Este paso es **CRÍTICO** porque los procesos en Assembly leen desde un archivo externo.

```bash
python3 data/generate_temp_binary.py
```

**Salida esperada:**
```
Generated temps_baseline.bin with 100 bytes
First 10 values: [55, 58, 62, 67, 72, 78, 85, 92, 95, 98]
Anomaly points (>90): [7, 8, 9, 10, 11, 32, 33, 34, 35, 36, 37, 97, 98, 99]
```

**✅ Esto confirma que:**
- Se creó el archivo `data/temps_baseline.bin`
- Contiene 100 bytes (1 por cada minuto de órbita)
- Hay 14 puntos con anomalías de temperatura (>90°C)

---

### Paso 2.4: Compilar el Proyecto

```bash
make all
```

**Salida esperada (últimas líneas):**
```
riscv64-unknown-elf-gcc -march=rv32i_zicsr_zifencei -mabi=ilp32 -nostdlib \
  -nostartfiles -T linker.ld -Wl,--no-relax -o bin/satellite_os.elf \
  build/src/kernel/*.o build/src/processes/*.o build/src/drivers/*.o \
  build/src/lib/*.o -lgcc
/usr/lib/.../ld: warning: bin/satellite_os.elf has a LOAD segment with RWX permissions
riscv64-unknown-elf-objdump -D bin/satellite_os.elf > bin/satellite_os.asm
```

**⚠️ Nota:** El warning sobre RWX permissions es **normal** en bare-metal.

---

### Paso 2.5: Verificar Tamaño del Binario

```bash
riscv64-unknown-elf-size bin/satellite_os.elf
```

**Salida esperada:**
```
   text    data     bss     dec     hex filename
  14640    4096     584   19320    4b78 bin/satellite_os.elf
```

**✅ Esto confirma:**
- Binario compilado correctamente (~19KB)
- Los procesos en Assembly están incluidos

---

## 3. Ejecución de los 4 Escenarios

### 🎯 Escenario 1: BASELINE (Round-Robin)

Este es el escenario **por defecto** ya configurado.

#### Paso 3.1.1: Verificar Configuración

Abre `src/kernel/main.c` y verifica la línea 32:

```c
scheduler_init(SCHED_BASELINE);
```

#### Paso 3.1.2: Ejecutar (con timeout de 10 segundos)

```bash
timeout 10 make run-with-data
```

#### Paso 3.1.3: Salida Esperada

```
Loading temperature data from data/temps_baseline.bin to address 0x80020000
qemu-system-riscv32 -machine virt -nographic -bios none -kernel bin/satellite_os.elf \
    -device loader,file=data/temps_baseline.bin,addr=0x80020000

=== Satellite Thermal Control System ===
RISC-V RV32I Kernel
UTEC - Computing Systems Final Project

[METRICS] Performance tracking initialized
[INIT] Performance metrics initialized
[INIT] Satellite state initialized
[PROCESS] All processes initialized
[SCHEDULER] Initialized in mode: BASELINE (Sequential)
[KERNEL] Starting process execution...

[SCHEDULER] Starting execution loop

--- Executing Process 1 ---
[P1] SENSING PHASE | Reading sensor... | Temperature: TEMP:55C

--- Executing Process 2 ---
[P2] Cooling standby | Temp: TEMP:55C

--- Executing Process 3 ---
======== [P3] SATELLITE TELEMETRY DISPLAY ========
[P3] Temperature: TEMP:55C
[P3] Cooling System: STANDBY
[P3] Orbital Zone: BRIGHT (Sun exposure)
[P3] Orbit Minute: 0 / 100
[P3] System Status: NOMINAL
==================================================

========================================
[SCHEDULER] Cycle 1 completed
========================================
```

**🔍 Observa que:**
- ✅ Lee temperatura correcta: 55°C (primer valor del archivo)
- ✅ Procesos ejecutan en orden: P1 → P2 → P3
- ✅ Cooling en STANDBY (temp < 90°C)
- ✅ Sistema funciona correctamente

---

#### Paso 3.1.4: Ver Activación del Cooling

Continúa ejecutando (o ejecuta con más tiempo) para ver cuando la temperatura sube:

```bash
timeout 60 make run-with-data 2>&1 | grep -A 5 "COOLING SYSTEM ACTIVATED"
```

**Salida esperada:**
```
*** [P2] COOLING SYSTEM ACTIVATED ***
[P2] Temperature exceeded threshold: TEMP:92C
[P2] Deploying thermal management techniques...
[P2] Activation PC: 0x800XXXXX
```

**🔍 Observa que:**
- ✅ Se activa cuando temp > 90°C (minuto 7)
- ✅ **Captura el PC** (Program Counter) al activarse
- ✅ Muestra el PC en hexadecimal

---

### 🎯 Escenario 2: PRIORITY_1 (P1→P3→P2)

#### Paso 3.2.1: Cambiar Configuración

Edita `src/kernel/main.c` línea 32:

```c
scheduler_init(SCHED_PRIORITY_1);  // Cambiar de SCHED_BASELINE
```

#### Paso 3.2.2: Recompilar

```bash
make clean && make all
```

#### Paso 3.2.3: Ejecutar

```bash
timeout 10 make run-with-data
```

**Salida esperada:**
```
[SCHEDULER] Initialized in mode: PRIORITY_1 (P1->P3->P2)

--- Executing Process 1 ---
[P1] SENSING PHASE | Reading sensor... | Temperature: TEMP:55C

--- Executing Process 3 ---
======== [P3] SATELLITE TELEMETRY DISPLAY ========
[P3] Temperature: TEMP:55C
...

--- Executing Process 2 ---
[P2] Cooling standby | Temp: TEMP:55C
```

**🔍 Observa que:**
- ✅ Orden cambia a: P1 → P3 → P2
- ✅ P2 ejecuta después de P3 (no consecutivo)

---

### 🎯 Escenario 3: PRIORITY_2 (P2→P1→P3)

#### Paso 3.3.1: Cambiar Configuración

```c
scheduler_init(SCHED_PRIORITY_2);
```

#### Paso 3.3.2: Recompilar y Ejecutar

```bash
make clean && make all
timeout 10 make run-with-data
```

**Salida esperada:**
```
[SCHEDULER] Initialized in mode: PRIORITY_2 (P2->P1->P3)

--- Executing Process 2 ---
[P2] Cooling standby | Temp: TEMP:55C

--- Executing Process 1 ---
[P1] SENSING PHASE | Reading sensor... | Temperature: TEMP:55C

--- Executing Process 3 ---
...
```

**🔍 Observa que:**
- ✅ Orden cambia a: P2 → P1 → P3
- ✅ P2 ejecuta primero (prioridad al cooling)

---

### 🎯 Escenario 4: SYSCALLS (Context Switching)

#### Paso 3.4.1: Cambiar Configuración

```c
scheduler_init(SCHED_SYSCALLS);
```

#### Paso 3.4.2: Recompilar y Ejecutar

```bash
make clean && make all
timeout 10 make run-with-data
```

**Salida esperada:**
```
[SCHEDULER] Initialized in mode: SYSCALLS (Automatic)

--- Executing Process 1 ---
[P1] SENSING PHASE | Reading sensor... | Temperature: TEMP:55C

--- Executing Process 2 ---
[P2] Cooling standby | Temp: TEMP:55C

--- Executing Process 3 ---
...
```

**🔍 Observa que:**
- ✅ Context switching automático
- ✅ Preserva PC usando CSR mepc
- ✅ Guarda/restaura todos los 32 registros

---

## 4. Qué Mostrar a la Profesora

### 📊 Demostración Completa (15-20 minutos)

#### **1. Mostrar el Código Assembly de los Procesos (5 min)**

```bash
# Mostrar proceso P1 (primeras 50 líneas)
cat src/processes/process_p1.S | head -50

# Mostrar proceso P2
cat src/processes/process_p2.S | head -80
```

**Explicar:**
- ✅ Procesos escritos en Assembly RISC-V RV32
- ✅ Sin instrucciones `rem`/`div` (implementación manual)
- ✅ Captura de PC con `csrr mepc`
- ✅ Lectura de temperatura desde memoria `0x80020000`

---

#### **2. Mostrar Sistema de Datos Externos (3 min)**

```bash
# Mostrar archivo de temperaturas
cat data/temps_baseline.txt

# Mostrar script generador
cat data/generate_temp_binary.py
```

**Explicar:**
- ✅ Cumple requisito de "archivos de entrada" del PDF
- ✅ 100 minutos de órbita LEO
- ✅ Anomalías en minutos específicos
- ✅ QEMU carga datos en memoria

---

#### **3. Demostrar Compilación (2 min)**

```bash
make clean
python3 data/generate_temp_binary.py
make all
riscv64-unknown-elf-size bin/satellite_os.elf
```

**Explicar:**
- ✅ Compilación exitosa
- ✅ Binario de ~19KB
- ✅ Flags RV32I puros

---

#### **4. Ejecutar Escenario BASELINE (5 min)**

```bash
timeout 60 make run-with-data 2>&1 | tee output_baseline.txt
```

**Mostrar en tiempo real:**
- ✅ Lectura de temperaturas desde archivo
- ✅ Activación de cooling cuando temp > 90°C
- ✅ **Captura de PC mostrada en pantalla**
- ✅ Desactivación cuando temp < 55°C (CORREGIDO)

**Búsqueda rápida de puntos clave:**
```bash
grep "COOLING SYSTEM ACTIVATED" output_baseline.txt
grep "COOLING SYSTEM DEACTIVATED" output_baseline.txt
grep "PC:" output_baseline.txt
```

---

#### **5. Cambiar a Escenario PRIORITY_1 (3 min)**

```bash
# Editar main.c (mostrar cambio)
nano src/kernel/main.c  # Cambiar línea 32

# Recompilar
make clean && make all

# Ejecutar
timeout 20 make run-with-data
```

**Mostrar:**
- ✅ Orden de procesos cambia
- ✅ Sistema sigue funcionando
- ✅ Diferencia visible en ejecución

---

#### **6. Mostrar Archivos del Proyecto (2 min)**

```bash
# Estructura del proyecto
tree -L 2 src/

# Procesos en Assembly
ls -lh src/processes/*.S

# Backup de versión en C
ls -lh src/processes/backup_c/
```

**Explicar:**
- ✅ Versiones originales en C guardadas en backup
- ✅ Nuevas versiones en Assembly (.S)
- ✅ Estructura organizada del proyecto

---

### 📸 Capturas de Pantalla Recomendadas

Toma capturas de pantalla de:

1. **Compilación exitosa:**
   ```bash
   make all
   ```

2. **Ejecución mostrando activación de cooling:**
   ```bash
   timeout 60 make run-with-data 2>&1 | grep -A 10 "ACTIVATED"
   ```

3. **PC capturado:**
   ```bash
   timeout 60 make run-with-data 2>&1 | grep "PC:"
   ```

4. **Los 4 escenarios diferentes:**
   - Captura del mensaje de inicialización de cada uno

5. **Código Assembly:**
   - Captura de `process_p1.S` mostrando captura de PC
   - Captura de `process_p2.S` mostrando umbrales

---

## 5. Troubleshooting

### ❌ Error: "temps_baseline.bin: No such file"

**Solución:**
```bash
python3 data/generate_temp_binary.py
```

---

### ❌ Error: "riscv64-unknown-elf-gcc: command not found"

**Solución:**
Instalar toolchain RISC-V. En Ubuntu/Debian:
```bash
sudo apt-get install gcc-riscv64-unknown-elf
```

---

### ❌ Error: "qemu-system-riscv32: command not found"

**Solución:**
```bash
sudo apt-get install qemu-system-misc
```

---

### ❌ QEMU no se cierra automáticamente

**Solución 1:** Usar `timeout`
```bash
timeout 10 make run-with-data
```

**Solución 2:** Presionar `Ctrl+A` luego `X` para salir manualmente

---

### ❌ Temperatura muestra valores incorrectos

**Problema:** Archivo binario no generado o corrupto

**Solución:**
```bash
rm data/temps_baseline.bin
python3 data/generate_temp_binary.py
make clean && make all
```

---

### ❌ Error de compilación: "unrecognized opcode 'rem'"

**Problema:** Ya corregido en la versión actual

**Verificación:**
```bash
grep -n "rem " src/processes/*.S
```
No debería encontrar nada.

---

## 6. Cambiar Datos de Temperatura

### Crear un Archivo de Prueba Personalizado

#### Paso 6.1: Editar Script

```bash
nano data/generate_temp_binary.py
```

Modifica el array `temperature_data` con tus propios valores.

#### Paso 6.2: Generar Nuevo Archivo

```bash
python3 data/generate_temp_binary.py
```

#### Paso 6.3: Ejecutar con Nuevos Datos

```bash
make run-with-data
```

---

### Ejemplo: Archivo con Temperaturas Extremas

```python
# En generate_temp_binary.py
temperature_data = [
    # Primeros 10 minutos: calor extremo
    95, 96, 97, 98, 99, 100, 101, 102, 103, 104,
    # Siguientes 10: frío extremo
    45, 46, 47, 48, 49, 50, 51, 52, 53, 54,
    # ... resto de valores ...
]
```

**Resultado esperado:**
- Cooling se activa inmediatamente
- Múltiples alertas
- Desactivación cuando baja a <55°C

---

## 📝 Checklist de Demostración

Usa esta lista antes de mostrar a la profesora:

- [ ] Toolchain y QEMU instalados y funcionando
- [ ] Archivo `temps_baseline.bin` generado
- [ ] Proyecto compila sin errores
- [ ] Tamaño del binario verificado (~19KB)
- [ ] Escenario BASELINE funciona
- [ ] Se observa activación de cooling
- [ ] PC capturado se muestra en pantalla
- [ ] Umbral de desactivación es 55°C (no 60°C)
- [ ] Los 4 escenarios probados
- [ ] Código Assembly visible y comentado
- [ ] Capturas de pantalla tomadas
- [ ] README.md actualizado revisado

---

## 🎓 Puntos Clave para la Presentación

### ✅ Cumplimiento de Requisitos

**Decir a la profesora:**

1. "Los procesos están implementados en **Assembly RISC-V RV32**, no en C"
   - Mostrar archivos `.S` en `src/processes/`

2. "Capturamos el **Program Counter (PC)** usando el CSR mepc"
   - Mostrar línea de código: `csrr t1, mepc`
   - Mostrar salida con PC en hexadecimal

3. "Leemos temperaturas desde **archivos externos**"
   - Mostrar `data/temps_baseline.bin`
   - Explicar QEMU device loader

4. "El umbral de desactivación es **<55°C**, no 60°C"
   - Mostrar `satellite.h:19`
   - Mostrar proceso P2 con umbral 55

5. "Implementamos **división/módulo manual** sin extensión M"
   - Mostrar loops de división en process_p3.S

---

## 🚀 Comando Rápido para Demo

**Un solo comando que hace todo:**

```bash
#!/bin/bash
# demo.sh - Script de demostración completo

echo "=== GENERANDO DATOS ==="
python3 data/generate_temp_binary.py

echo ""
echo "=== COMPILANDO ==="
make clean && make all

echo ""
echo "=== VERIFICANDO BINARIO ==="
riscv64-unknown-elf-size bin/satellite_os.elf

echo ""
echo "=== EJECUTANDO (60 segundos) ==="
timeout 60 make run-with-data

echo ""
echo "=== DEMOSTRACIÓN COMPLETA ==="
```

Guarda esto como `demo.sh` y ejecuta:
```bash
chmod +x demo.sh
./demo.sh
```

---

**¿Listo para la demostración?** 🎯

Si tienes dudas sobre algún paso, pregunta antes de mostrar a la profesora.
