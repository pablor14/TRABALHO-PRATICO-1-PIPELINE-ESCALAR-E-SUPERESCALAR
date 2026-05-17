# =============================================================================
# S3 — Sequência com Load-Use Hazard (Irredutível)
# Arquitetura de Computadores III — Trabalho Prático: Pipeline
#
# Hazard predominante: Load-Use Hazard — o ÚNICO stall irredutível
#                      no pipeline de 5 estágios com forwarding completo
#
# OBJETIVO: demonstrar analiticamente por que este stall não pode ser
#           eliminado por forwarding, e mostrar as únicas soluções possíveis.
#
# POR QUE O FORWARDING NÃO RESOLVE O LOAD-USE:
#
#   Ciclo:   1    2    3    4    5    6    7
#   lw  x10: IF   ID   EX  MEM  WB
#   add x11:      IF   ID  ***  EX  MEM  WB
#                           ↑
#                     stall (bolha)
#
#   O valor de x10 só está disponível ao FINAL do estágio MEM (ciclo 4).
#   A instrução add precisa do valor no INÍCIO do estágio EX (ciclo 4).
#   Há uma contradição temporal: não é possível usar o valor antes de ele
#   existir. O forwarding MEM/WB→EX só funciona quando o produtor está
#   em MEM e o consumidor está em EX — mas neste caso ambos precisariam
#   estar no mesmo ciclo, o que é impossível no pipeline de 5 estágios.
#
# SOLUÇÕES POSSÍVEIS:
#   (1) Stall de 1 ciclo (interlocking por hardware) — reduz IPC
#   (2) Reordenação de instruções pelo compilador (code scheduling)
#       — mover uma instrução independente para entre lw e add
#       — veja a versão otimizada ao final deste arquivo
#
# ANÁLISE ESPERADA:
#   Versão original (3 pares load-use):
#     - 3 stalls irredutíveis (1 por par)
#     - 7 instruções efetivas + 3 stalls = 10 ciclos
#     - CPI = 10/7 ≈ 1,43
#
#   Versão reordenada (load-use eliminado por escalonamento):
#     - 0 stalls de load-use
#     - CPI ≈ 1,0
# =============================================================================

.data
base:   .word  15, 28, 37      # três valores na memória

.text
.globl _start
_start:

    la   x5, base            # x5 = endereço base do array

    # ==================================================================
    # VERSÃO ORIGINAL: load seguido imediatamente de instrução dependente
    # ==================================================================

    # Par 1: load-use com instrução add
    lw   x10, 0(x5)          # x10 = mem[base+0] = 15
    add  x11, x10, x6        # ★ USE x10 (dist=1) → STALL irredutível
                              #   x11 = x10 + x6

    # Par 2: load-use com instrução sub
    lw   x12, 4(x5)          # x12 = mem[base+4] = 28
    sub  x13, x12, x6        # ★ USE x12 (dist=1) → STALL irredutível
                              #   x13 = x12 - x6

    # Par 3: load-use com instrução add envolvendo dois loads dependentes
    lw   x14, 8(x5)          # x14 = mem[base+8] = 37
    add  x15, x14, x11       # ★ USE x14 (dist=1) → STALL irredutível
                              #   x15 = x14 + x11
                              #   (x11 já está disponível — sem stall em x11)

    # Armazena resultado (sem dependência imediata)
    sw   x15, 12(x5)         # mem[base+12] = x15

    # ------------------------------------------------------------------
    # Ponto de parada
    # ------------------------------------------------------------------
    addi a7, zero, 10
    ecall

# =============================================================================
# VERSÃO OTIMIZADA — escalonamento estático pelo compilador
# (PARA COMPARAÇÃO: insira abaixo de _start para testar no simulador)
#
# A instrução "sw x15, 12(x5)" é independente dos loads e pode ser
# reordenada para preencher o slot de delay do load-use.
# Analogamente, "sub x13..." pode ser movido após o terceiro lw.
#
# Reordenação que elimina TODOS os load-use stalls:
#
#     la   x5,  base
#     lw   x10, 0(x5)         # carrega x10
#     lw   x12, 4(x5)         # independente: preenche delay slot de x10
#     add  x11, x10, x6       # x10 já disponível (dist=2 após reordenação)
#     lw   x14, 8(x5)         # independente: preenche delay slot de x12
#     sub  x13, x12, x6       # x12 já disponível (dist=2)
#     sw   x13, 12(x5)        # independente: preenche delay slot de x14
#     add  x15, x14, x11      # x14 já disponível (dist=2)
#
# → Resultado idêntico, CPI ≈ 1,0, 0 stalls de load-use.
# =============================================================================

# =============================================================================
# VERSÃO MIPS (WinDLX / MARS) — descomente para usar
# =============================================================================
#
# .data
# base: .word 15, 28, 37
#
# .text
# .globl main
# main:
#     la    $t5, base
#     lw    $t0, 0($t5)       # carrega 15
#     add   $t1, $t0, $t6    # ★ load-use em t0
#     lw    $t2, 4($t5)       # carrega 28
#     sub   $t3, $t2, $t6    # ★ load-use em t2
#     lw    $t4, 8($t5)       # carrega 37
#     add   $t7, $t4, $t1    # ★ load-use em t4
#     sw    $t7, 12($t5)      # armazena resultado
#     addiu $v0, $zero, 10
#     syscall
#
# =============================================================================
# QUESTÕES PARA O RELATÓRIO:
#   Q1. Desenhe o diagrama de estágios para o Par 1 (lw + add), mostrando
#       o stall. Em qual ciclo o valor de x10 estaria disponível? Em qual
#       ciclo add precisaria dele? Por que o forwarding não resolve?
#   Q2. Habilite o forwarding no simulador e verifique que o stall ainda
#       ocorre. O que o simulador mostra no diagrama de estágios?
#   Q3. Implemente a versão reordenada (descrita acima) e compare o CPI
#       com a versão original. Qual é o speedup?
#   Q4. Em processadores reais (ex.: ARM Cortex-A53), a latência do load
#       é tipicamente de 4 ciclos (L1 cache hit). Quantos stalls ocorreriam
#       nesse caso? Como o processador mitiga isso?
# =============================================================================
