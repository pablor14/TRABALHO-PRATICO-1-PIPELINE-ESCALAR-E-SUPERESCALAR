# =============================================================================
# S1 — Cadeia RAW Direta
# Arquitetura de Computadores III — Trabalho Prático: Pipeline
#
# Hazard predominante: Data Hazard RAW (distância 1 instrução)
# Objetivo: observar stalls sem forwarding; eliminação com forwarding
#
# COMO USAR NO RIPES:
#   1. Abrir o RIPES e selecionar o processador "5-Stage Processor"
#   2. Carregar este arquivo em File > Load Program
#   3. Executar em modo "Pause on hazard" para observar cada stall
#   4. Repetir habilitando "Enable Forwarding" e comparar os ciclos
#
# COMO USAR NO MARS (MIPS):
#   Ver a versão MIPS no final deste arquivo (comentada)
#
# ANÁLISE ESPERADA (pipeline 5 estágios, sem forwarding):
#   Cada instrução add/sub que usa o resultado da anterior gera 2 stalls
#   (o resultado só está disponível no estágio WB, 2 ciclos depois de EX).
#   Total de stalls esperado: 2 stalls × 5 dependências = 10 stalls
#   CPI esperado sem forwarding : (7 inst + 10 stalls) / 7 inst ≈ 2,43
#   CPI esperado com forwarding : próximo de 1,0 (forwarding EX/MEM→EX elimina tudo)
#
# DEPENDÊNCIAS PRESENTES:
#   I1 → I2 : RAW em t1  (dist. 1)  ← stall de 2 ciclos sem forwarding
#   I2 → I3 : RAW em t2  (dist. 1)  ← stall de 2 ciclos
#   I3 → I4 : RAW em t3  (dist. 1)  ← stall de 2 ciclos
#   I4 → I5 : RAW em t4  (dist. 1)  ← stall de 2 ciclos
#   I5 → I6 : RAW em t5  (dist. 1)  ← stall de 2 ciclos
#   I6 → I7 : RAW em t6  (dist. 1)  ← forwarding MEM/WB→EX necessário
#   Nenhuma dependência WAR ou WAW nesta sequência
# =============================================================================

.text
.globl _start
_start:

    # ------------------------------------------------------------------
    # Inicialização dos valores de entrada
    # ------------------------------------------------------------------
    addi t0, zero, 10       # t0 = 10  (valor semente)

    # ------------------------------------------------------------------
    # Cadeia de dependências RAW com distância 1
    # Cada instrução usa IMEDIATAMENTE o resultado da anterior
    # ------------------------------------------------------------------
    add  t1, t0, t0         # [I2] t1 = t0 + t0 = 20   RAW em t0 (dist=1)
    add  t2, t1, t0         # [I3] t2 = t1 + t0 = 30   RAW em t1 (dist=1)
    add  t3, t2, t1         # [I4] t3 = t2 + t1 = 50   RAW em t2 (dist=1)
    add  t4, t3, t2         # [I5] t4 = t3 + t2 = 80   RAW em t3 (dist=1)
    add  t5, t4, t3         # [I6] t5 = t4 + t3 = 130  RAW em t4 (dist=1)
    sub  t6, t5, t4         # [I7] t6 = t5 - t4 = 50   RAW em t5 (dist=1)

    # Resultado final em t6 = 50
    # Verificar: t1=20, t2=30, t3=50, t4=80, t5=130, t6=50

    # ------------------------------------------------------------------
    # Ponto de parada (RIPES termina no ecall; MARS usa syscall)
    # ------------------------------------------------------------------
    addi a7, zero, 10       # syscall: exit
    ecall

# =============================================================================
# VERSÃO MIPS (para WinDLX / MARS) — descomente para usar no MARS
# =============================================================================
#
# .text
# .globl main
# main:
#     addiu $t0, $zero, 10    # t0 = 10
#     add   $t1, $t0, $t0     # t1 = 20   RAW em t0 (dist=1)
#     add   $t2, $t1, $t0     # t2 = 30   RAW em t1 (dist=1)
#     add   $t3, $t2, $t1     # t3 = 50   RAW em t2 (dist=1)
#     add   $t4, $t3, $t2     # t4 = 80   RAW em t3 (dist=1)
#     add   $t5, $t4, $t3     # t5 = 130  RAW em t4 (dist=1)
#     sub   $t6, $t5, $t4     # t6 = 50   RAW em t5 (dist=1)
#     addiu $v0, $zero, 10    # syscall exit
#     syscall
#
# =============================================================================
# QUESTÕES PARA O RELATÓRIO:
#   Q1. Trace o diagrama de estágios (IF ID EX MEM WB) para as instruções
#       I2–I4 sem forwarding. Quais ciclos contêm bolhas (NOP)?
#   Q2. Com forwarding EX/MEM→EX habilitado, algum stall ainda ocorre?
#       Justifique com base nos estágios do pipeline.
#   Q3. Reordene as instruções para eliminar os hazards sem alterar o
#       resultado final. É possível eliminar TODOS os stalls?
#   Q4. Qual seria o CPI se houvesse uma instrução independente entre
#       cada par dependente (distância 2)?
# =============================================================================
