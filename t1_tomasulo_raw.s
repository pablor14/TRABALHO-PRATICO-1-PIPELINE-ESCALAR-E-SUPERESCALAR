; =============================================================================
; T1 — Dependências RAW em Cadeia (Ponto Flutuante)
; Arquitetura de Computadores III — Trabalho Prático: Pipeline
; Algoritmo de Tomasulo — Simulação Manual (Parte B.1)
;
; Formato: DLX Assembly (compatível com WinDLX)
; Versão MIPS FP comentada ao final (compatível com SPIM/MARS)
;
; OBJETIVO:
;   Simular o Algoritmo de Tomasulo ciclo a ciclo, preenchendo as tabelas:
;     (1) Instruction Status       — Issue / Exec Start / Exec End / Write Result
;     (2) Reservation Stations     — busy, op, Vj, Vk, Qj, Qk
;     (3) Register Result Status   — Qi para cada registrador
;     (4) CDB Broadcasts           — qual RS transmitiu, em qual ciclo, qual valor
;
; PARÂMETROS DO HARDWARE (conforme especificação do TP):
;   Reservation Stations:
;     Load1, Load2          — para instruções LD / LF
;     Add1, Add2, Add3      — para ADDD e SUBD
;     Mult1, Mult2          — para MULTD e DIVD
;
;   Latências de execução (ciclos dentro da unidade funcional):
;     LD            : 2 ciclos
;     ADD.D / SUB.D : 2 ciclos
;     MUL.D         : 4 ciclos
;     DIV.D         : 8 ciclos
;
;   Restrições:
;     - 1 instrução despachada (Issue) por ciclo, EM ORDEM
;     - CDB compartilhado: apenas 1 broadcast por ciclo
;     - Retirada em ordem via ROB (não modelada neste exercício)
;
; =============================================================================
; ESTADO INICIAL DOS REGISTRADORES (valores hipotéticos para rastreamento):
;   R2 = 100  (endereço base)
;   R3 = 200  (endereço base)
;   F4 = 2.0  (constante)
;   F2, F0, F6, F8, F10 = indefinido (serão escritos pela sequência)
; =============================================================================
;
; GRAFO DE DEPENDÊNCIAS:
;
;   I1 ──(F6)──► I4 ──(F8)──► I6
;   I2 ──(F2)──► I3 ──(F0)──► I5
;   I2 ──(F2)──────────────► I4
;   I2 ──(F2)──────────────► I6
;   I1 ──(F6)──────────────► I5
;
;   Todas as dependências são RAW (verdadeiras).
;   NÃO há WAR nem WAW nesta sequência.
;   Isso é intencional: o Tomasulo deve explorar paralelismo
;   onde possível (I1 e I2 são independentes entre si).
;
; ANÁLISE DE PARALELISMO:
;   - I1 e I2 podem ser despachadas em ciclos consecutivos e
;     executadas em paralelo nas Load Units.
;   - I3 e I4 aguardam resultados distintos: I3 espera F2 (de I2),
;     I4 espera F6 (de I1) e F2 (de I2).
;   - I5 só pode iniciar após I3 terminar (F0) e I1 terminar (F6).
;   - I6 só pode iniciar após I4 (F8) e I2 (F2) estarem prontos.
;   - I5 (DIVD, 8 ciclos) será o gargalo da execução.
;
; CAMINHO CRÍTICO: I2 → I3 → I5   (2 + 4 + 8 = 14 ciclos de execução)
;
; =============================================================================

        .data
; Endereços de memória (valores inicializados para simulação)
mem_34: .double 3.5          ; mem[34+R2] = 3.5  → será F6
mem_45: .double 2.0          ; mem[45+R3] = 2.0  → será F2

        .text
        .global main

main:
        ; Carrega R2 e R3 com endereços base
        addi    R2, R0, 0        ; R2 = 0  (base para LD de F6)
        addi    R3, R0, 0        ; R3 = 0  (base para LD de F2)
        addf    F4, F0, F0       ; F4 = 0.0 + 0.0 = 0.0 (placeholder; valor real = 2.0)

        ; -----------------------------------------------------------------
        ; SEQUÊNCIA T1 — 6 instruções com dependências RAW em cadeia
        ; -----------------------------------------------------------------

        LD   F6,  34(R2)    ; [I1] F6  ← mem[R2+34] = 3.5
                             ;      Escreve: F6
                             ;      Lê:     R2 (inteiro, disponível imediatamente)
                             ;      Issue → Load1 ou Load2
                             ;      Sem dependência de dados (operando inteiro)

        LD   F2,  45(R3)    ; [I2] F2  ← mem[R3+45] = 2.0
                             ;      Escreve: F2
                             ;      Lê:     R3 (inteiro, disponível imediatamente)
                             ;      Issue → Load1 ou Load2 (o outro não usado por I1)
                             ;      Sem dependência de dados

        MULTD F0, F2, F4    ; [I3] F0  ← F2 × F4   (4 ciclos de EX)
                             ;      Escreve: F0
                             ;      Lê:     F2 (produzido por I2 — RAW I2→I3)
                             ;              F4 (disponível; valor constante)
                             ;      Issue → Mult1 ou Mult2
                             ;      No Issue: Qj = nome da RS de I2 (ainda executando)
                             ;                Vk = valor atual de F4

        SUBD  F8, F6, F2    ; [I4] F8  ← F6 - F2   (2 ciclos de EX)
                             ;      Escreve: F8
                             ;      Lê:     F6 (produzido por I1 — RAW I1→I4)
                             ;              F2 (produzido por I2 — RAW I2→I4)
                             ;      Issue → Add1, Add2 ou Add3
                             ;      No Issue: Qj = RS de I1; Qk = RS de I2
                             ;      Aguarda ambos os loads completarem

        DIVD  F10, F0, F6   ; [I5] F10 ← F0 / F6   (8 ciclos de EX — GARGALO)
                             ;      Escreve: F10
                             ;      Lê:     F0 (produzido por I3 — RAW I3→I5)
                             ;              F6 (produzido por I1 — RAW I1→I5)
                             ;      Issue → Mult1 ou Mult2 (o não usado por I3)
                             ;      ★ Nota: ocupa RS por 8 ciclos após F0 disponível

        ADDD  F6, F8, F2    ; [I6] F6  ← F8 + F2   (2 ciclos de EX)
                             ;      Escreve: F6  ← SOBRESCREVE o valor de I1!
                             ;      Lê:     F8 (produzido por I4 — RAW I4→I6)
                             ;              F2 (produzido por I2 — RAW I2→I6)
                             ;      Issue → Add1, Add2 ou Add3
                             ;      ★ Nota: o Tomasulo garantiu que I5 capturou
                             ;        F6 de I1 (no Qj) antes de I6 sobrescrevê-lo.
                             ;        Se houvesse WAW aqui, o ROB garantiria a ordem.

        halt

; =============================================================================
; VALORES ESPERADOS AO FINAL (com F4 = 2.0):
;   F6  = F8 + F2  = (F6_original - F2) + F2 = F6_original = 3.5
;         (I6 sobrescreve I1, mas o valor coincide neste caso específico)
;   F2  = 2.0  (de I2)
;   F0  = F2 × F4 = 2.0 × 2.0 = 4.0  (de I3)
;   F8  = F6 - F2 = 3.5 - 2.0 = 1.5  (de I4)
;   F10 = F0 / F6 = 4.0 / 3.5 ≈ 1.143 (de I5, usa F6 de I1 = 3.5)
;   F6  = F8 + F2 = 1.5 + 2.0 = 3.5  (de I6)
; =============================================================================

; =============================================================================
; TABELA DE DEPENDÊNCIAS (RAW) — para o relatório:
;
;  Produtora → Consumidora  │ Registrador │ Tipo
;  ─────────────────────────┼─────────────┼──────
;  I1        → I4           │  F6         │ RAW
;  I1        → I5           │  F6         │ RAW
;  I2        → I3           │  F2         │ RAW
;  I2        → I4           │  F2         │ RAW
;  I2        → I6           │  F2         │ RAW
;  I3        → I5           │  F0         │ RAW
;  I4        → I6           │  F8         │ RAW
;
;  Nenhuma dependência WAR ou WAW nesta sequência.
; =============================================================================

; =============================================================================
; VERSÃO MIPS FP (SPIM / MARS) — descomente para usar
; =============================================================================
;
; .data
; val_f6: .double 3.5
; val_f2: .double 2.0
; val_f4: .double 2.0
;
; .text
; .globl main
; main:
;     la    $t0, val_f6
;     l.d   $f6,  0($t0)      ; I1: F6 ← 3.5
;     la    $t1, val_f2
;     l.d   $f2,  0($t1)      ; I2: F2 ← 2.0
;     la    $t2, val_f4
;     l.d   $f4,  0($t2)      ; F4 ← 2.0 (constante)
;     mul.d $f0,  $f2, $f4    ; I3: F0 ← F2 × F4
;     sub.d $f8,  $f6, $f2    ; I4: F8 ← F6 - F2
;     div.d $f10, $f0, $f6    ; I5: F10 ← F0 / F6
;     add.d $f6,  $f8, $f2    ; I6: F6 ← F8 + F2
;     li    $v0, 10
;     syscall
;
; =============================================================================
; QUESTÕES PARA O RELATÓRIO:
;   Q1. Preencha a tabela Instruction Status para todas as instruções.
;       Em qual ciclo cada instrução é despachada (Issue)?
;       Em qual ciclo começa e termina a execução?
;       Em qual ciclo escreve o resultado no CDB?
;   Q2. Preencha a tabela Reservation Station para os ciclos 1 a 6.
;       Quais RSs ficam em espera (busy=yes, mas Qj ou Qk ≠ 0)?
;   Q3. Qual RS está aguardando o resultado de qual outra RS?
;       Desenhe o grafo de RSs aguardando (dependência via Tomasulo).
;   Q4. Em qual ciclo o DIVD (I5) pode iniciar execução?
;       Qual é o ciclo de término e de Write Result de I5?
;   Q5. Existe conflito no CDB? (dois resultados prontos no mesmo ciclo?)
;       Se sim, qual tem prioridade e como o outro é atrasado?
; =============================================================================
