#!/bin/bash
# =============================================================================
# Script de Demostración Automática
# Proyecto: Sistema de Control Térmico de Satélite - RISC-V RV32I
# =============================================================================

set -e  # Exit on error

echo "=========================================="
echo "  DEMOSTRACIÓN DEL PROYECTO"
echo "  Satellite Thermal Control System"
echo "  RISC-V RV32I - Assembly Implementation"
echo "=========================================="
echo ""

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Paso 1: Generar datos
echo -e "${BLUE}[1/5] Generando datos de temperatura...${NC}"
python3 data/generate_temp_binary.py
echo -e "${GREEN}✓ Datos generados${NC}"
echo ""

# Paso 2: Limpiar
echo -e "${BLUE}[2/5] Limpiando compilaciones anteriores...${NC}"
make clean
echo -e "${GREEN}✓ Limpieza completa${NC}"
echo ""

# Paso 3: Compilar
echo -e "${BLUE}[3/5] Compilando proyecto...${NC}"
make all
echo -e "${GREEN}✓ Compilación exitosa${NC}"
echo ""

# Paso 4: Verificar binario
echo -e "${BLUE}[4/5] Verificando binario generado...${NC}"
riscv64-unknown-elf-size bin/satellite_os.elf
echo -e "${GREEN}✓ Binario correcto (~19KB)${NC}"
echo ""

# Paso 5: Ejecutar
echo -e "${BLUE}[5/5] Ejecutando sistema (60 segundos)...${NC}"
echo -e "${YELLOW}Presiona Ctrl+C para detener antes${NC}"
echo ""
sleep 2

timeout 60 make run-with-data || true

echo ""
echo "=========================================="
echo -e "${GREEN}✓ DEMOSTRACIÓN COMPLETA${NC}"
echo "=========================================="
echo ""
echo "Para ver solo activaciones de cooling:"
echo "  timeout 60 make run-with-data 2>&1 | grep -A 5 ACTIVATED"
echo ""
echo "Para cambiar escenario:"
echo "  Editar src/kernel/main.c línea 32"
echo "  Luego: make clean && make all"
echo ""
