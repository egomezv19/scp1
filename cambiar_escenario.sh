#!/bin/bash

# Script para cambiar fácilmente entre escenarios

ARCHIVO="src/kernel/main.c"

case "$1" in
    1|baseline|BASELINE)
        sed -i 's/scheduler_init(SCHED_[A-Z_0-9]*);/scheduler_init(SCHED_BASELINE);/' "$ARCHIVO"
        echo "✅ Cambiado a ESCENARIO 1: BASELINE"
        ;;
    2|priority1|PRIORITY_1)
        sed -i 's/scheduler_init(SCHED_[A-Z_0-9]*);/scheduler_init(SCHED_PRIORITY_1);/' "$ARCHIVO"
        echo "✅ Cambiado a ESCENARIO 2: PRIORITY_1"
        ;;
    3|priority2|PRIORITY_2)
        sed -i 's/scheduler_init(SCHED_[A-Z_0-9]*);/scheduler_init(SCHED_PRIORITY_2);/' "$ARCHIVO"
        echo "✅ Cambiado a ESCENARIO 3: PRIORITY_2"
        ;;
    4|syscalls|SYSCALLS)
        sed -i 's/scheduler_init(SCHED_[A-Z_0-9]*);/scheduler_init(SCHED_SYSCALLS);/' "$ARCHIVO"
        echo "✅ Cambiado a ESCENARIO 4: SYSCALLS"
        ;;
    *)
        echo "❌ Uso: $0 [1|2|3|4]"
        echo ""
        echo "Escenarios disponibles:"
        echo "  1 o baseline   - BASELINE (P1→P2→P3)"
        echo "  2 o priority1  - PRIORITY_1 (P1→P3→P2)"
        echo "  3 o priority2  - PRIORITY_2 (P2→P1→P3)"
        echo "  4 o syscalls   - SYSCALLS (con context switching)"
        exit 1
        ;;
esac

# Verificar el cambio
echo ""
echo "📝 Verificación:"
grep "scheduler_init" "$ARCHIVO" | sed 's/^[ \t]*//'

