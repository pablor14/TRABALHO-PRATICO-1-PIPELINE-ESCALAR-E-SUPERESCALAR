# =============================================================================
# S5 — Código com Múltiplos Desvios Condicionais (Padrões Mistos)
# Arquitetura de Computadores III — Trabalho Prático: Pipeline
#
# Hazard predominante: Hazard de controle com padrões mixed taken/not-taken
# Objetivo: comparar o desempenho dos preditores estático e dinâmico
#           (1 bit e 2 bits / saturating counter)
#
# DESCRIÇÃO DO PROGRAMA:
#   Classifica um array de 10 inteiros em três categorias:
#     - negativos  (val < 0)
#     - zeros      (val = 0)
#     - positivos  (val > 0)
#   Conta quantos elementos há em cada categoria.
#
# PADRÃO DE DESVIOS gerado pelos dados do array:
#   Array: [-3, 5, 0, 2, -1, 0, 7, -4, 0, 3]
#
#   Iteração │ val  │ blt(neg?) │ beq(zero?) │ blt→pos?
#   ─────────┼──────┼───────────┼────────────┼─────────
#      1      │  -3  │  T (taken)│  —         │  —
#      2      │   5  │  N (n.t.) │  N (n.t.)  │  N→pos
#      3      │   0  │  N (n.t.) │  T (taken) │  —
#      4      │   2  │  N (n.t.) │  N (n.t.)  │  N→pos
#      5      │  -1  │  T (taken)│  —         │  —
#      6      │   0  │  N (n.t.) │  T (taken) │  —
#      7      │   7  │  N (n.t.) │  N (n.t.)  │  N→pos
#      8      │  -4  │  T (taken)│  —         │  —
#      9      │   0  │  N (n.t.) │  T (taken) │  —
#     10      │   3  │  N (n.t.) │  N (n.t.)  │  N→pos
#   ─────────┴──────┴───────────┴────────────┴─────────
#   blt neg:  T N N N T N N T N N  (3 taken, 7 not-taken)
#   beq zero: — N T N — T N — T N  (3 taken, 4 not-taken considerando execuções)
#   bge pos:  — N — N — — N — — N  (sempre not-taken pois é o fall-through)
#
# ANÁLISE DOS PREDITORES:
#
#   Preditor ESTÁTICO (always not-taken):
#     blt neg:  3 mispredictions (quando taken)
#     beq zero: 3 mispredictions
#     Total: 6+ flushes × penalidade por flush
#
#   Preditor de 1 BIT:
#     Muda de estado após cada predição errada.
#     Para blt neg (padrão T N N N T N N T N N):
#       Estado inicial: NT (não-taken)
#       Iter 1: prev=NT, real=T  → mispred (muda para T)
#       Iter 2: prev=T,  real=N  → mispred (muda para NT)
#       Iter 3: prev=NT, real=N  → acerto
#       Iter 4: prev=NT, real=N  → acerto
#       Iter 5: prev=NT, real=T  → mispred (muda para T)
#       Iter 6: prev=T,  real=N  → mispred (muda para NT)
#       ...
#     Para blt neg: 6 mispredictions em 10 iterações → taxa de acerto 40%
#
#   Preditor de 2 BITS (saturating counter: SNT=00, WNT=01, WT=10, ST=11):
#     Estado inicial: WNT (01)
#     Para blt neg (T N N N T N N T N N):
#       Iter 1: pred=N (WNT), real=T  → mispred → WT (10)
#       Iter 2: pred=T (WT),  real=N  → mispred → WNT (01)
#       Iter 3: pred=N (WNT), real=N  → acerto  → SNT (00)
#       Iter 4: pred=N (SNT), real=N  → acerto  → SNT (00)
#       Iter 5: pred=N (SNT), real=T  → mispred → WNT (01)
#       Iter 6: pred=N (WNT), real=N  → acerto  → SNT (00)
#       Iter 7: pred=N (SNT), real=N  → acerto  → SNT (00)
#       Iter 8: pred=N (SNT), real=T  → mispred → WNT (01)
#       Iter 9: pred=N (WNT), real=N  → acerto  → SNT (00)
#       Iter 10:pred=N (SNT), real=N  → acerto  → SNT (00)
#     Para blt neg: 4 mispredictions em 10 iterações → taxa de acerto 60%
#
#   CONCLUSÃO: 2 bits supera 1 bit pois resiste melhor a desvios esporádicos.
# =============================================================================

.data
# Array com padrão misto: negativos, zeros e positivos
array:  .word  -3, 5, 0, 2, -1, 0, 7, -4, 0, 3
N:      .word  10       # tamanho do array

.text
.globl _start
_start:

    # ------------------------------------------------------------------
    # Inicialização dos contadores e ponteiro
    # ------------------------------------------------------------------
    la   x5,  array         # x5  = endereço base do array
    lw   x6,  N             # x6  = 10 (número de elementos)
    addi x7,  zero, 0       # x7  = 0  (contador de negativos)
    addi x8,  zero, 0       # x8  = 0  (contador de zeros)
    addi x9,  zero, 0       # x9  = 0  (contador de positivos)
    addi x10, zero, 0       # x10 = 0  (índice i)

    # ------------------------------------------------------------------
    # Loop principal de classificação
    # ------------------------------------------------------------------
    #
    # Estrutura de desvios por iteração:
    #
    #   blt x11, zero, neg   ← desvio 1: padrão T/N misto
    #   beq x11, zero, zer   ← desvio 2: padrão T/N misto (se não negativo)
    #   (fall-through = positivo)
    #   j   fim_class        ← desvio incondicional (sempre taken)
    #
    # Obs: o desvio blt é o mais "difícil" para os preditores porque
    #      seu padrão muda com frequência.

loop:
    bge  x10, x6, sair      # [B0] se i >= 10, termina  (taken na última iter.)

    # Carrega elemento atual: x11 = array[i]
    slli x12, x10, 2        # x12 = i * 4  (offset em bytes)
    add  x13, x5, x12       # x13 = endereço de array[i]
    lw   x11, 0(x13)        # x11 = array[i]             (load-use hazard aqui!)

    # ------------------------------------------------------------------
    # Classificação: 3 desvios condicionais por iteração
    # ------------------------------------------------------------------

    blt  x11, zero, neg     # [B1] se array[i] < 0 → é negativo   (padrão misto)
    beq  x11, zero, zer     # [B2] se array[i] = 0 → é zero       (padrão misto)

    # fall-through: é positivo
    addi x9, x9, 1          # positivos++
    j    fim_class           # [B3] pula para fim_class             (sempre taken)

neg:
    addi x7, x7, 1          # negativos++
    j    fim_class           # [B4] pula para fim_class             (sempre taken)

zer:
    addi x8, x8, 1          # zeros++
    # (sem desvio: cai direto em fim_class)

fim_class:
    addi x10, x10, 1        # i++
    j    loop                # [B5] volta ao início do loop         (sempre taken)

sair:
    # ------------------------------------------------------------------
    # Resultados em:
    #   x7 = 3  (negativos: -3, -1, -4)
    #   x8 = 3  (zeros:      0,  0,  0)
    #   x9 = 4  (positivos:  5,  2,  7,  3)
    # ------------------------------------------------------------------
    addi a7, zero, 10
    ecall

# =============================================================================
# VERSÃO MIPS (WinDLX / MARS) — descomente para usar
# =============================================================================
#
# .data
# array: .word -3, 5, 0, 2, -1, 0, 7, -4, 0, 3
# N:     .word 10
#
# .text
# .globl main
# main:
#     la    $t5, array
#     lw    $t6, N
#     addiu $t7, $zero, 0     # negativos
#     addiu $t8, $zero, 0     # zeros
#     addiu $t9, $zero, 0     # positivos
#     addiu $t0, $zero, 0     # i
# loop:
#     bge   $t0, $t6, sair    # se i >= 10, termina
#     sll   $t2, $t0, 2       # offset
#     add   $t3, $t5, $t2     # endereço
#     lw    $t1, 0($t3)       # val = array[i]
#     bltz  $t1, neg          # se negativo
#     beqz  $t1, zer          # se zero
#     addiu $t9, $t9, 1       # positivos++
#     j     fim
# neg:addiu $t7, $t7, 1       # negativos++
#     j     fim
# zer:addiu $t8, $t8, 1       # zeros++
# fim:addiu $t0, $t0, 1       # i++
#     j     loop
# sair:
#     addiu $v0, $zero, 10
#     syscall
#
# =============================================================================
# QUESTÕES PARA O RELATÓRIO:
#   Q1. Para o desvio B1 (blt — negativo?), simule manualmente os preditores
#       de 1 bit e 2 bits para as 10 iterações. Use o padrão de ocorrências:
#       T N N N T N N T N N
#       Calcule a taxa de acerto de cada preditor.
#   Q2. Para o desvio B2 (beq — zero?), repita a análise.
#       Padrão (considerando apenas quando B1 não foi taken): N T N N T N N T N
#   Q3. Calcule o CPI total do loop para:
#       (a) sem predição (assume always not-taken, penalidade = 1 ciclo por flush)
#       (b) preditor de 1 bit
#       (c) preditor de 2 bits
#   Q4. Como o padrão de desvios mudaria se o array estivesse ordenado?
#       Qual preditor se beneficiaria mais de um array ordenado?
#   Q5. Proponha uma transformação do código (ex.: separar o array em duas
#       passagens) que tornasse os padrões de desvio mais previsíveis.
# =============================================================================
