# =============================================================================
# S2 — Loop com Dependência de Variável de Indução
# Arquitetura de Computadores III — Trabalho Prático: Pipeline
#
# Hazard predominante: Data Hazard RAW em loop + Branch Hazard
# Objetivo: quantificar a interação entre data hazard e hazard de controle
#
# DESCRIÇÃO DO PROGRAMA:
#   Calcula a soma dos elementos de um array de 8 inteiros.
#   soma = a[0] + a[1] + ... + a[7]
#
# ANÁLISE ESPERADA:
#   Sem forwarding, sem predição (assume not-taken):
#     - Stalls RAW no corpo do loop: load-use (lw→add) = 1 stall irredutível
#     - Stall de branch (bne): 1 stall por tomada (penalty de controle)
#     - Por iteração: ~3 stalls + 1 flush (branch taken) = 4 penalidades
#     - Total (8 iterações × 5 inst.): 40 instruções + 32 penalidades
#     - CPI ≈ (40 + 32) / 40 = 1,80
#
#   Com forwarding + predição dinâmica de 2 bits:
#     - Load-use: 1 stall irredutível permanece por iteração
#     - Preditor 2 bits: após 2 iterações, prediz "taken" → 0 flushes (iter. 1-7)
#     - Última iteração (bne not-taken): 1 flush de misprediction
#     - CPI ≈ (40 + 8 + 1) / 40 ≈ 1,23
#
# DEPENDÊNCIAS POR ITERAÇÃO:
#   lw  x13, 0(x12)        → produz x13
#   add x10, x10, x13      → RAW em x13 (load-use, dist=1) ← IRREDUTÍVEL
#   addi x12, x12, 4       → RAW em x12 (dist=1 de addi anterior na iter. seguinte)
#   addi x11, x11, -1      → RAW em x11 (dist=1)
#   bne  x11, zero, loop   → RAW em x11 (dist=1) + Branch hazard
# =============================================================================

.data
# Array de 8 inteiros (4 bytes cada)
array:  .word  3, 7, 2, 9, 1, 5, 8, 4

.text
.globl _start
_start:

    # ------------------------------------------------------------------
    # Inicialização
    # ------------------------------------------------------------------
    addi x10, zero, 0       # x10 = 0  (acumulador da soma)
    addi x11, zero, 8       # x11 = 8  (contador de iterações)
    la   x12, array         # x12 = endereço base do array

    # ------------------------------------------------------------------
    # Corpo do loop
    # ------------------------------------------------------------------
    #
    #  Mapa de dependências dentro do loop:
    #
    #  ┌─────────────────────────────────────────────────────────────┐
    #  │  lw   x13, 0(x12)   → escreve x13                          │
    #  │  add  x10, x10, x13 → RAW em x13 (load-use, dist=1) ★     │
    #  │  addi x12, x12, 4   → escreve x12 (usado na próx. iter.)   │
    #  │  addi x11, x11, -1  → escreve x11 (RAW em x11, dist=1)     │
    #  │  bne  x11, zero, loop→ RAW em x11 (dist=1) + branch hazard  │
    #  └─────────────────────────────────────────────────────────────┘
    #
    #  ★ O load-use (lw → add) é o único hazard irredutível:
    #    mesmo com forwarding, o valor de x13 só estará disponível no
    #    final do estágio MEM, mas add precisa dele no início de EX.
    #    Solução: inserir NOP ou reordenar (mover addi x12 para entre
    #    lw e add resolve o stall sem alterar a semântica).

loop:
    lw   x13, 0(x12)        # x13 = array[i]          (MEM access)
    add  x10, x10, x13      # soma += x13   ★ load-use (RAW, dist=1)
    addi x12, x12, 4        # x12 += 4      (avança ponteiro)
    addi x11, x11, -1       # x11 -= 1      (decrementa contador)
    bne  x11, zero, loop    # se x11≠0, volta ao loop  (branch taken 7×)

    # ------------------------------------------------------------------
    # Fim: resultado da soma em x10
    # Valor esperado: 3+7+2+9+1+5+8+4 = 39  → x10 = 39
    # ------------------------------------------------------------------
    addi a7, zero, 10
    ecall

# =============================================================================
# VERSÃO MIPS (WinDLX / MARS) — descomente para usar
# =============================================================================
#
# .data
# array: .word 3, 7, 2, 9, 1, 5, 8, 4
#
# .text
# .globl main
# main:
#     addiu $t0, $zero, 0     # acumulador
#     addiu $t1, $zero, 8     # contador
#     la    $t2, array        # endereço base
# loop:
#     lw    $t3, 0($t2)       # carrega elemento
#     add   $t0, $t0, $t3    # soma += elem   (load-use!)
#     addiu $t2, $t2, 4       # avança ponteiro
#     addiu $t1, $t1, -1      # decrementa contador
#     bne   $t1, $zero, loop  # repete se não terminou
#     addiu $v0, $zero, 10
#     syscall
#
# =============================================================================
# QUESTÕES PARA O RELATÓRIO:
#   Q1. Trace o diagrama de estágios das 3 primeiras iterações do loop
#       (a) sem forwarding e (b) com forwarding. Quantos stalls em cada caso?
#   Q2. Reordene as instruções dentro do loop para eliminar o load-use stall
#       sem inserir NOPs. A semântica do programa é preservada?
#       DICA: a instrução addi x12, x12, 4 pode ser movida entre lw e add.
#   Q3. Simule o preditor de 1 bit e o de 2 bits para os 8 desvios bne.
#       Padrão real: TTTTTTTTN (7 taken, 1 not-taken). Qual preditor erra menos?
#   Q4. Qual é o impacto do branch delay slot (MIPS) nesta sequência?
# =============================================================================
