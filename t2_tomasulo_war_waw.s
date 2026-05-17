; =============================================================================
; T2 — Anti-dependências (WAR) e Dependências de Saída (WAW)
; Arquitetura de Computadores III — Trabalho Prático: Pipeline
; Algoritmo de Tomasulo — Simulação Manual (Parte B.1 + Parte B.2)
;
; Formato: DLX Assembly (compatível com WinDLX)
; Versão MIPS FP comentada ao final (compatível com SPIM/MARS)
;
; OBJETIVO PRIMÁRIO:
;   Demonstrar como o Algoritmo de Tomasulo elimina automaticamente
;   hazards WAR e WAW por meio da renomeação implícita de registradores
;   via Reservation Stations (Vj/Vk capturam valores no Issue;
;   Qj/Qk rastreiam produtores pendentes por RS, não por nome de reg.).
;
; OBJETIVO SECUNDÁRIO (Parte B.2):
;   Esta mesma sequência é usada no exercício de renomeação EXPLÍCITA
;   com Register Alias Table (RAT), onde o aluno renomeia manualmente
;   cada instrução e mostra que WAR e WAW desaparecem.
;
; PARÂMETROS DO HARDWARE (mesmos de T1):
;   Add1, Add2, Add3  → ADDD / SUBD  (2 ciclos de EX)
;   Mult1, Mult2      → MULTD         (4 ciclos de EX)
;                     → DIVD          (8 ciclos de EX)
;   Load1, Load2      → LD            (2 ciclos de EX)
;   1 Issue por ciclo (em ordem) | CDB compartilhado (1 broadcast/ciclo)
;
; =============================================================================
; ESTADO INICIAL DOS REGISTRADORES:
;   F0  = 1.0     F2  = 2.0     F4  = 3.0
;   F6  = 4.0     F8  = 0.5     F10 = 6.0
;   (valores hipotéticos para rastrear dependências)
; =============================================================================
;
; GRAFO DE DEPENDÊNCIAS COMPLETO:
;
;   Legenda: ──RAW──►  dependência verdadeira (necessária)
;            ~~WAR~~►  anti-dependência (falsa — eliminada pelo Tomasulo)
;            ==WAW==►  dependência de saída (falsa — eliminada pelo Tomasulo)
;
;   I1: DIVD  F0, F2, F4
;   I2: MULTD F6, F0, F8
;   I3: ADDD  F2, F6, F4
;   I4: MULTD F8, F2, F6
;   I5: SUBD  F0, F8, F6
;   I6: ADDD  F4, F0, F2
;
;   RAW (dependências verdadeiras — Tomasulo rastreia via Qj/Qk):
;     I1 → I2 : F0   (I2 lê F0 produzido por I1)
;     I2 → I3 : F6   (I3 lê F6 produzido por I2)
;     I2 → I4 : F6   (I4 lê F6 produzido por I2)
;     I3 → I4 : F2   (I4 lê F2 produzido por I3)
;     I4 → I5 : F8   (I5 lê F8 produzido por I4)
;     I2 → I5 : F6   (I5 lê F6 produzido por I2)
;     I5 → I6 : F0   (I6 lê F0 produzido por I5)
;     I3 → I6 : F2   (I6 lê F2 produzido por I3)
;
;   WAR (anti-dependências — Tomasulo elimina capturando valor no Issue):
;     I1 → I3 : F2   (I1 LÊ F2 como operando; I3 ESCREVE F2 depois)
;               ★ Em OoO sem renomeação: se I3 for adiantada e escrever F2
;                 antes de I1 ler F2 → I1 leria valor errado (novo F2).
;               ✓ Tomasulo: I1 captura o valor de F2 em Vj no ciclo do Issue.
;                 I3 pode escrever F2 quando quiser — I1 já tem sua cópia.
;
;     I2 → I4 : F8   (I2 LÊ F8 como operando; I4 ESCREVE F8 depois)
;               ★ Em OoO: se I4 escrever F8 antes de I2 ler F8 de I1 → WAR.
;               ✓ Tomasulo: I2 captura F8 em Vk (ou Qk←Mult para F0) no Issue.
;                 F8 é capturado imediatamente pois ainda não há produtor pendente.
;
;     I2 → I5 : F0   (I2 LÊ F0 de I1; I5 ESCREVE F0 depois)
;               ★ Em OoO: se I5 terminar e escrever F0 antes de I2 usar
;                 o F0 correto de I1 → I2 leria valor errado.
;               ✓ Tomasulo: I2 registra Qj←Mult1 (RS de I1) no Issue.
;                 Quando I1 escreve no CDB, I2 captura o valor correto.
;
;     I1 → I6 : F4   (I1 LÊ F4 como operando; I6 ESCREVE F4 depois)
;               ★ Em OoO: se I6 escrever F4 antes de I1 ler F4 → WAR.
;               ✓ Tomasulo: I1 captura F4 em Vk no Issue (F4 disponível).
;
;   WAW (dependências de saída — Tomasulo elimina pelo rastreamento no ROB):
;     I1 → I5 : F0   (I1 escreve F0 primeiro; I5 escreve F0 depois)
;               O valor FINAL de F0 deve ser o de I5.
;               ★ Em pipeline sem ROB: se I5 escrever antes de I1 → WAW.
;               ✓ Tomasulo + ROB: o Register Result Status aponta para I5.
;                 Quando I1 escreve no CDB, ninguém mais espera por ele
;                 (I2 já capturou via CDB broadcast no momento certo).
;
;     I3 → I6 → (F2 não é WAW pois I3 escreve F2 e I6 lê F2 → RAW)
;     Nota: I6 escreve F4 e I1 também leu F4 (não escreve F4) → sem WAW em F4.
;
;   RESUMO DE FALSAS DEPENDÊNCIAS eliminadas pelo Tomasulo:
;     4 WAR  (I1→I3/F2, I2→I4/F8, I2→I5/F0, I1→I6/F4)
;     1 WAW  (I1→I5/F0)
;
; =============================================================================
;
; POR QUE O TOMASULO ELIMINA WAR E WAW — MECANISMO:
;
;   WAR: Ao fazer o Issue de instrução I com operando F_x, o Tomasulo
;        imediatamente copia o valor atual de F_x para Vj (ou Vk) na RS,
;        OU registra o nome da RS produtora em Qj (ou Qk).
;        → Assim, mesmo que uma instrução posterior SOBRESCREVA F_x,
;          I já tem sua própria cópia do valor correto.
;
;   WAW: O Register Result Status (campo Qi de cada registrador) sempre
;        aponta para a ÚLTIMA instrução que escreve naquele registrador.
;        → Quando uma instrução anterior completa e tenta escrever via CDB,
;          as RSs que aguardam esse valor já foram atualizadas pelos
;          broadcasts corretos. O ROB assegura que o valor "visible"
;          externamente é o da instrução mais recente (em ordem).
;
; =============================================================================

        .text
        .global main

main:
        ; Inicialização (em um processador real, estes valores
        ; estariam no banco de registradores FP)
        ; F0=1.0, F2=2.0, F4=3.0, F6=4.0, F8=0.5, F10=6.0

        ; -----------------------------------------------------------------
        ; SEQUÊNCIA T2 — 6 instruções com RAW, WAR e WAW
        ; -----------------------------------------------------------------

        DIVD  F0, F2, F4    ; [I1] F0  ← F2 / F4 = 2.0 / 3.0 ≈ 0.667   (8 ciclos)
                             ;      Escreve: F0  ← versão 1 de F0
                             ;      Lê:     F2 (= 2.0, capturado em Vj no Issue)
                             ;              F4 (= 3.0, capturado em Vk no Issue)
                             ;      Issue → Mult1 (ou Mult2)
                             ;      WAR: I1 lê F2 → I3 escreverá F2 depois (WAR I1→I3)
                             ;      WAR: I1 lê F4 → I6 escreverá F4 depois (WAR I1→I6)
                             ;      WAW: I1 escreve F0 → I5 também escreverá F0 (WAW I1→I5)

        MULTD F6, F0, F8    ; [I2] F6  ← F0 × F8 = 0.667 × 0.5 ≈ 0.333 (4 ciclos)
                             ;      Escreve: F6  ← versão 2 de F6 (sobrescreve F6=4.0)
                             ;      Lê:     F0 (pendente → Qj ← RS de I1)
                             ;              F8 (= 0.5, capturado em Vk no Issue)
                             ;      Issue → Mult2 (ou Mult1)
                             ;      RAW: I2 aguarda F0 de I1  (Qj = Mult1)
                             ;      WAR: I2 lê F8 → I4 escreverá F8 depois (WAR I2→I4)
                             ;      WAR: I2 lê F0 de I1 via CDB → I5 escreverá F0 (WAR I2→I5)

        ADDD  F2, F6, F4    ; [I3] F2  ← F6 + F4   (2 ciclos)
                             ;      Escreve: F2  ← versão 2 de F2 (sobrescreve F2=2.0)
                             ;      Lê:     F6 (pendente → Qj ← RS de I2)
                             ;              F4 (= 3.0, capturado em Vk no Issue)
                             ;      Issue → Add1
                             ;      RAW: I3 aguarda F6 de I2  (Qj = Mult2)
                             ;      ★ WAR I1→I3 eliminado: I1 já capturou F2=2.0 em Vj no Issue
                             ;        I3 pode escrever F2 quando quiser

        MULTD F8, F2, F6    ; [I4] F8  ← F2 × F6   (4 ciclos)
                             ;      Escreve: F8  ← versão 2 de F8 (sobrescreve F8=0.5)
                             ;      Lê:     F2 (pendente → Qj ← RS de I3)
                             ;              F6 (pendente → Qk ← RS de I2)
                             ;      Issue → Mult1 (liberado após I1 concluir ou Mult2)
                             ;      RAW: I4 aguarda F2 de I3 (Qj = Add1)
                             ;      RAW: I4 aguarda F6 de I2 (Qk = Mult2)
                             ;      ★ WAR I2→I4 eliminado: I2 capturou F8=0.5 em Vk no Issue

        SUBD  F0, F8, F6    ; [I5] F0  ← F8 - F6   (2 ciclos)
                             ;      Escreve: F0  ← versão 2 de F0 (valor FINAL de F0)
                             ;      Lê:     F8 (pendente → Qj ← RS de I4)
                             ;              F6 (pendente → Qk ← RS de I2)
                             ;      Issue → Add2
                             ;      RAW: I5 aguarda F8 de I4 (Qj = Mult para I4)
                             ;      RAW: I5 aguarda F6 de I2 (Qk = Mult2)
                             ;      ★ WAW I1→I5 (F0): Register Result Status de F0
                             ;        aponta para RS de I5 (última escritora).
                             ;        Quando I1 escreve F0 no CDB, apenas as RSs
                             ;        aguardando I1 são atualizadas (RS de I2 → Vj).
                             ;        Ninguém mais aguarda I1 para F0.
                             ;      ★ WAR I2→I5 (F0) eliminado: I2 capturou Qj←Mult1
                             ;        no Issue (aguarda valor de I1 via CDB, não o
                             ;        registrador F0 diretamente).

        ADDD  F4, F0, F2    ; [I6] F4  ← F0 + F2   (2 ciclos)
                             ;      Escreve: F4  ← versão 2 de F4 (valor FINAL de F4)
                             ;      Lê:     F0 (pendente → Qj ← RS de I5)
                             ;              F2 (pendente → Qk ← RS de I3)
                             ;      Issue → Add3
                             ;      RAW: I6 aguarda F0 de I5 (Qj = Add2)
                             ;      RAW: I6 aguarda F2 de I3 (Qk = Add1)
                             ;      ★ WAR I1→I6 (F4) eliminado: I1 capturou F4=3.0
                             ;        em Vk no ciclo do seu Issue.

        halt

; =============================================================================
; CÁLCULO DOS VALORES FINAIS (para verificação após a simulação):
;   F2_inicial = 2.0, F4_inicial = 3.0, F6_inicial = 4.0, F8_inicial = 0.5
;
;   I1: F0_v1 = F2_ini / F4_ini = 2.0 / 3.0 ≈ 0.6667
;   I2: F6_v2 = F0_v1 × F8_ini = 0.6667 × 0.5 ≈ 0.3333
;   I3: F2_v2 = F6_v2 + F4_ini = 0.3333 + 3.0  ≈ 3.3333
;   I4: F8_v2 = F2_v2 × F6_v2 = 3.3333 × 0.3333 ≈ 1.1111
;   I5: F0_v2 = F8_v2 - F6_v2 = 1.1111 - 0.3333 ≈ 0.7778  ← valor FINAL de F0
;   I6: F4_v2 = F0_v2 + F2_v2 = 0.7778 + 3.3333 ≈ 4.1111  ← valor FINAL de F4
;
;   Registros com valor "visível" alterado em relação ao estado inicial:
;     F0 : 1.0 → 0.7778  (I1 escreve versão 1; I5 escreve versão final)
;     F2 : 2.0 → 3.3333  (I3 sobrescreve)
;     F4 : 3.0 → 4.1111  (I6 sobrescreve)
;     F6 : 4.0 → 0.3333  (I2 sobrescreve)
;     F8 : 0.5 → 1.1111  (I4 sobrescreve)
; =============================================================================

; =============================================================================
; TABELA DE DEPENDÊNCIAS — PARA PREENCHER NO RELATÓRIO:
;
;  De\Para │  I1    I2    I3    I4    I5    I6
;  ─────────┼──────────────────────────────────────
;    I1     │  —    RAW   WAR   —     WAW   WAR
;           │       (F0)  (F2)        (F0)  (F4)
;    I2     │  —     —    RAW   RAW   RAW   —
;           │             (F6)  (F6)  (F0→via CDB)
;           │                   WAR   WAR
;           │                   (F8)  (F0→via I1)
;    I3     │  —     —     —    RAW   —     RAW
;           │                   (F2)        (F2)
;    I4     │  —     —     —     —    RAW   —
;           │                         (F8)
;    I5     │  —     —     —     —     —    RAW
;           │                               (F0)
;    I6     │  —     —     —     —     —    —
;
; LEGENDA: RAW = dependência verdadeira | WAR = anti-dep. | WAW = dep. de saída
; =============================================================================

; =============================================================================
; VERSÃO MIPS FP (SPIM / MARS) — descomente para usar
; =============================================================================
;
; .data
; v_f0: .double 1.0
; v_f2: .double 2.0
; v_f4: .double 3.0
; v_f6: .double 4.0
; v_f8: .double 0.5
;
; .text
; .globl main
; main:
;     la    $t0, v_f0 ; carrega endereços
;     l.d   $f0,  0($t0)
;     la    $t0, v_f2
;     l.d   $f2,  0($t0)
;     la    $t0, v_f4
;     l.d   $f4,  0($t0)
;     la    $t0, v_f6
;     l.d   $f6,  0($t0)
;     la    $t0, v_f8
;     l.d   $f8,  0($t0)
;
;     div.d  $f0, $f2, $f4   ; I1
;     mul.d  $f6, $f0, $f8   ; I2
;     add.d  $f2, $f6, $f4   ; I3
;     mul.d  $f8, $f2, $f6   ; I4
;     sub.d  $f0, $f8, $f6   ; I5
;     add.d  $f4, $f0, $f2   ; I6
;
;     li    $v0, 10
;     syscall
;
; =============================================================================
; QUESTÕES PARA O RELATÓRIO:
;   Q1. Preencha a tabela Instruction Status para T2.
;       Compare com T1: T2 tem mais ou menos ciclos até Write Result final?
;       Por quê? (dica: DIV.D de 8 ciclos em I1 vs. dois LDs em T1)
;
;   Q2. No ciclo de Issue de I1, quais são os valores de Vj, Vk, Qj, Qk
;       na Reservation Station? E para I2?
;       Demonstre que o valor de F2 (= 2.0) foi capturado em Vj de I1
;       antes de I3 poder sobrescrevê-lo → WAR I1→I3 eliminado.
;
;   Q3. Para o WAW entre I1 e I5 (ambas escrevem F0):
;       (a) Em qual ciclo I1 faz Write Result de F0?
;       (b) Em qual ciclo I5 faz Write Result de F0?
;       (c) O Register Result Status de F0 aponta para qual RS antes
;           do Write Result de I1? E depois?
;       (d) A instrução I2 (que aguarda F0 de I1) recebe o valor correto
;           ou o de I5? Justifique pelo funcionamento do CDB.
;
;   Q4. Parte B.2 — Renomeação explícita com RAT:
;       Aplique renomeação de registradores físicos P0–P15 (inicialmente
;       mapeados: F0→P0, F2→P2, F4→P4, F6→P6, F8→P8).
;       Produza a sequência renomeada e o estado do RAT após cada instrução.
;       Quantas dependências WAR e WAW foram eliminadas?
;       Qual é o ILP máximo após a renomeação?
;
;   Q5. Qual é o caminho crítico de T2 (em ciclos de execução)?
;       Compare com T1. Qual sequência permite maior ILP?
; =============================================================================
