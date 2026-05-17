# =============================================================================
# S4 — Bloco com Anti-dependências (WAR) e Dependências de Saída (WAW)
# Arquitetura de Computadores III — Trabalho Prático: Pipeline
#
# Hazard predominante: WAR (Write After Read) e WAW (Write After Write)
# Objetivo: base para a análise de renomeação de registradores (Parte B)
#
# DEFINIÇÕES:
#   RAW (Read After Write / dependência verdadeira):
#     Instrução J lê um registrador que instrução I ainda vai escrever.
#     → hazard REAL: o dado ainda não existe
#
#   WAR (Write After Read / anti-dependência):
#     Instrução J escreve em um registrador que instrução I ainda vai ler.
#     → hazard FALSO: o registrador é reutilizado cedo demais
#     → resolvido por renomeação de registradores
#
#   WAW (Write After Write / dependência de saída):
#     Instrução J escreve em um registrador que instrução I também escreve.
#     → hazard FALSO: o valor intermediário é sobrescrito
#     → resolvido por renomeação de registradores
#
# GRAFO DE DEPENDÊNCIAS desta sequência:
#
#   I1: add  x1, x2, x3    escreve x1;  lê  x2, x3
#   I2: sub  x4, x1, x5    escreve x4;  lê  x1, x5
#   I3: add  x2, x6, x7    escreve x2;  lê  x6, x7
#   I4: mul  x1, x4, x8    escreve x1;  lê  x4, x8
#   I5: add  x5, x1, x2    escreve x5;  lê  x1, x2
#   I6: sub  x4, x5, x9    escreve x4;  lê  x5, x9
#
#   RAW (dependências verdadeiras — NÃO eliminadas por renomeação):
#     I1 → I2 : x1  (I2 lê o x1 escrito por I1)
#     I2 → I4 : x4  (I4 lê o x4 escrito por I2)
#     I4 → I5 : x1  (I5 lê o x1 escrito por I4)
#     I3 → I5 : x2  (I5 lê o x2 escrito por I3)
#     I5 → I6 : x5  (I6 lê o x5 escrito por I5)
#
#   WAR (anti-dependências — eliminadas por renomeação):
#     I1 → I3 : x2  (I3 escreve x2 antes de I1 terminar de usar x2? NÃO —
#                    I1 lê x2 em ID, I3 escreve em WB mais tarde.
#                    Em pipeline IN-ORDER não há hazard aqui.
#                    Em OoO, I3 poderia escrever x2 antes de I1 ler → WAR!)
#     I2 → I5 : x5  (I5 escreve x5, mas I2 lê x5 — se I5 for adiantada, WAR)
#     I4 → I6 : x4  (I6 escreve x4, I4 lê x4 — se I6 for adiantada, WAR)
#
#   WAW (dependências de saída — eliminadas por renomeação):
#     I1 → I4 : x1  (ambas escrevem x1; o valor de I1 é consumido por I2 e I5,
#                    mas o valor "final" de x1 é o de I4)
#     I2 → I6 : x4  (ambas escrevem x4; o valor final de x4 é o de I6)
#
# EXERCÍCIO DE RENOMEAÇÃO (Parte B):
#   Use um RAT com registradores físicos P0–P15 para eliminar WAR e WAW.
#   Registradores arquiteturais: x1–x9 mapeados para P0–P8 inicialmente.
#   Produza a sequência renomeada e o estado do RAT após cada instrução.
# =============================================================================

.text
.globl _start
_start:

    # ------------------------------------------------------------------
    # Inicialização dos valores de entrada (sem dependências entre si)
    # ------------------------------------------------------------------
    addi x2, zero, 10    # x2 = 10
    addi x3, zero, 5     # x3 =  5
    addi x5, zero, 3     # x5 =  3
    addi x6, zero, 8     # x6 =  8
    addi x7, zero, 2     # x7 =  2
    addi x8, zero, 4     # x8 =  4
    addi x9, zero, 6     # x9 =  6

    # ------------------------------------------------------------------
    # Sequência S4 — 6 instruções com RAW, WAR e WAW
    # ------------------------------------------------------------------

    add  x1, x2, x3      # [I1] x1 = x2 + x3 = 15
                         #      escreve: x1 | lê: x2, x3

    sub  x4, x1, x5      # [I2] x4 = x1 - x5 = 12
                         #      escreve: x4 | lê: x1, x5
                         #      RAW I1→I2: x1 (dist=1) ← stall sem forwarding

    add  x2, x6, x7      # [I3] x2 = x6 + x7 = 10
                         #      escreve: x2 | lê: x6, x7
                         #      WAR I1→I3: x2 (OoO: I3 pode escrever x2 antes de I1 ler)

    mul  x1, x4, x8      # [I4] x1 = x4 * x8 = 48
                         #      escreve: x1 | lê: x4, x8
                         #      RAW I2→I4: x4 (dist=2) ← forwarding resolve
                         #      WAW I1→I4: x1 (I4 sobrescreve o x1 de I1)

    add  x5, x1, x2      # [I5] x5 = x1 + x2 = 58
                         #      escreve: x5 | lê: x1, x2
                         #      RAW I4→I5: x1 (dist=1) ← stall sem forwarding
                         #      RAW I3→I5: x2 (dist=2) ← forwarding resolve
                         #      WAR I2→I5: x5 (OoO: I5 pode escrever x5 antes de I2 ler)

    sub  x4, x5, x9      # [I6] x4 = x5 - x9 = 52
                         #      escreve: x4 | lê: x5, x9
                         #      RAW I5→I6: x5 (dist=1) ← stall sem forwarding
                         #      WAW I2→I6: x4 (I6 sobrescreve o x4 de I2)
                         #      WAR I4→I6: x4 (OoO: I6 pode escrever x4 antes de I4 ler)

    # ------------------------------------------------------------------
    # Resultados esperados:
    #   x1 = 48  (sobrescrito por I4 — valor de I1 foi consumido por I2)
    #   x2 = 10  (sobrescrito por I3)
    #   x4 = 52  (sobrescrito por I6 — valor de I2 foi consumido por I4)
    #   x5 = 58  (sobrescrito por I5 — valor inicial consumido por I2)
    # ------------------------------------------------------------------

    addi a7, zero, 10
    ecall

# =============================================================================
# TABELA DE DEPENDÊNCIAS PARA PREENCHER NO RELATÓRIO:
#
#  De \ Para │  I1   I2   I3   I4   I5   I6
#  ──────────┼────────────────────────────────
#      I1    │   —  RAW   WAR  WAW  —    —
#      I2    │   —   —    —   RAW  WAR  WAW
#      I3    │   —   —    —    —   RAW  —
#      I4    │   —   —    —    —   RAW  WAR
#      I5    │   —   —    —    —    —   RAW
#      I6    │   —   —    —    —    —    —
#
# ILP MÁXIMO (assumindo recursos ilimitados, apenas RAW limitam):
#   Conjunto independente máximo = {I1, I3} em paralelo
#   Depois: {I2, I3_concluída} → I2 depende de I1, I3 é independente
#   Análise de caminho crítico:
#     I1 → I2 → I4 → I5 → I6  (caminho mais longo: 5 dependências RAW)
#     I3 pode ser executada em paralelo com I1 ou I2
#   ILP máximo ≈ 6 instruções / 5 ciclos = 1,2 IPC
# =============================================================================

# =============================================================================
# VERSÃO MIPS (WinDLX / MARS) — descomente para usar
# =============================================================================
#
# .text
# .globl main
# main:
#     addiu $t2, $zero, 10
#     addiu $t3, $zero, 5
#     addiu $t5, $zero, 3
#     addiu $t6, $zero, 8
#     addiu $t7, $zero, 2
#     addiu $t8, $zero, 4
#     addiu $t9, $zero, 6
#
#     add  $t1, $t2, $t3     # I1
#     sub  $t4, $t1, $t5     # I2
#     add  $t2, $t6, $t7     # I3
#     mul  $t1, $t4, $t8     # I4
#     add  $t5, $t1, $t2     # I5
#     sub  $t4, $t5, $t9     # I6
#
#     addiu $v0, $zero, 10
#     syscall
#
# =============================================================================
# QUESTÕES PARA O RELATÓRIO:
#   Q1. Para cada par de instruções (I_i, I_j) com i < j, classifique a
#       dependência como RAW, WAR, WAW ou nenhuma. Use a tabela acima.
#   Q2. Aplique renomeação de registradores usando o RAT. Mostre o estado
#       do RAT após cada instrução e a sequência de instruções renomeadas.
#       Quantas dependências WAR e WAW foram eliminadas?
#   Q3. Após a renomeação, desenhe o grafo de dependências resultante
#       (apenas RAW). Qual é o caminho crítico? Qual é o ILP máximo?
#   Q4. Em um superescalar de 2 vias com OoO, quais instruções poderiam
#       ser despachadas em paralelo? Simule o despacho ciclo a ciclo.
# =============================================================================
