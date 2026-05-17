# TRABALHO-PRATICO-1-PIPELINE-ESCALAR-E-SUPERESCALAR
**Arquitetura de Computadores III — PUC Minas**  
 Curso: Engenharia da Computação
 
 Prof. Ricardo Carlini Sperandio · 1º Semestre / 2026

integrantes: Pablo Rodrigues, Thiago Marques e Paulo

 Este repositório contém os arquivos de simulação, relatório do TP1, guia 
 de execução disponível no README e a metodologia do trabalho.
 obs: As sequências S1–S5 foram fornecidas pelo professor e executadas 
 no MARS MIPS Simulator.
 
# relatorio em pdf
# pipeline: 
    s1_raw_chain.s          # S1: cadeia RAW com distância 1
    s2_loop_raw_branch.s    # S2: loop com RAW + branch hazard
    s3_load_use.s           # S3: load-use irredutível
    s4_war_waw.s            # S4: anti-dependências WAR e WAW
    s5_branches.s           # S5: múltiplos desvios condicionais

# tomasulo:
    t1_raw_chain_fp.s
    t2_war_waw_fp.s
  
# Como Executar no MARS

Baixar o MARS: http://courses.missouristate.edu/KenVollmar/MARS/
Instalar Java 8 ou superior
Executar: java -jar Mars4_5.jar,
File > Open → selecionar o arquivo .s,
Run > Assemble (F3) e 
Run > Step (F7) para avançar ciclo a ciclo

# metodologia
As simulações escalares (Parte A) foram realizadas no MARS nas configurações (a) a (e).
As configurações superescalares C1–C5 (Parte B) foram obtidas por modelagem
analítica baseada nos parâmetros medidos no MARS, uma vez que o simulador não suporta
despacho superescalar.

# gráficos e tabelas
 Os gráficos e tabelas analíticas presentes no relatório foram produzidos
manualmente utilizando Word e Excel, com base nos
dados coletados nas simulações no MARS e na modelagem analítica das
configurações superescalares.

# uso de IA
Não foram utilizados scripts de automação para geração de gráficos.
O uso de IA generativa (Claude — Anthropic) foi, conforme permitido pelo enunciado,
para auxílio na redação e análise dos resultados.
