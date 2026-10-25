# Objetivo geral (decidido em 25/10/2026)

**Pergunta de pesquisa:** sensibilidade a hiperparametros e potencial de ajuste de tres estimadores VIO
**tightly coupled** (um por filtro, dois por otimizacao), em hardware embarcado (Limo Pro, Orin Nano), sob
restricao de tempo real. (Nao se afirma nada sobre "paradigma X e mais sensivel": n=1 filtro vs n=2 otimizacao.)

| Metodo | Estimador | ROS 2 |
|---|---|---|
| OpenVINS | filtro (MSCKF) | oficial |
| OKVIS2 | otimizacao (keyframes) | oficial (modo mono nao testado) |
| VINS-Fusion mono+IMU | otimizacao (janela deslizante) | porta da comunidade |

ORB-SLAM3 descartado por ora (sem ROS 2 mono-inercial). Opcao futura: um segundo metodo por filtro com ROS 2 (a pesquisar) para o desenho 2x2.

## Plano
1. (etapa atual) Container ROS 2 Jazzy com os 3 metodos + drivers do Limo; enviar rota e gravar a pose/odometria do metodo em tempo real.
2. Escolher 5 hiperparametros por metodo com a MESMA funcao (n. de features, limiar/espacamento de deteccao,
   ruido da IMU, criterio de keyframe/janela, orcamento de computacao), justificados ANTES de ver resultados.
3. Optuna multiobjetivo (RMSE do ATE e uso de CPU) por metodo, num dataset de ajuste, um teste por vez,
   hardware fixo (idealmente o proprio Limo), mesmo numero de testes por metodo, penalidade igual para falhas.
4. fANOVA (avaliador do Optuna) sobre os testes: importancia de cada parametro.
5. Validar em OUTRA trajetoria: padrao vs ajustado vs pontos da frente de Pareto; repetir a melhor configuracao varias vezes.

## Cuidados
- Mesmo alinhamento (SE(3), escala em mono) em todos; mesmo evo.
- Tempo real e restricao: o que reduz RMSE costuma custar CPU/latencia (usar rt_monitor).
- Execucao em tempo real nao e deterministica: reportar media e desvio.
- Ajustar e avaliar na mesma sequencia = sobreajuste.
