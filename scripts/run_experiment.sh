#!/bin/bash
# Um experimento completo DENTRO do container: sobe drivers (se nao houver), o metodo VIO, grava a pose em tempo real
# (TUM), o bag e as metricas de tempo real, executa a rota e encerra tudo.
# Uso: run_experiment.sh <openvins|okvis2|vinsfusion> <reta|quadrado|oito|oval> <nome> [velocidade_m_s]
# Saidas em /data/results/<nome>/: <nome>_<metodo>.tum, bag/, rt_*.csv, *.log
# CUIDADO: o robo ANDA. Area livre e controle manual/botao de emergencia a mao.
set -m
M=$1; R=$2; N=$3; V=${4:-0.2}
[ -n "$M" ] && [ -n "$R" ] && [ -n "$N" ] || { sed -n 2,7p "$0"; exit 1; }
case $M in
  openvins)   RUN=run_openvins.sh;   POSE=/ov_msckf/poseimu;     TYPE=posecov; PROC=ov_msckf;   HZ=20;;
  okvis2)     RUN=run_okvis2.sh;     POSE=/okvis/okvis_odometry; TYPE=odom;    PROC=okvis_node; HZ=15;;
  vinsfusion) RUN=run_vinsfusion.sh; POSE=/odometry;             TYPE=odom;    PROC=vins_node;  HZ=10;;
  *) echo "metodo invalido: $M"; exit 1;;
esac
bash /opt/limo_vio/scripts/status.sh | grep -q "^$M .*OK" || { echo "ERRO: $M nao foi compilado nesta imagem (status.sh)"; exit 1; }
OUT=/data/results/$N; mkdir -p $OUT
PIDS=()
start() { local log=$1; shift; "$@" > $OUT/$log.log 2>&1 & PIDS+=($!); }
stop_all() { for p in "${PIDS[@]}"; do kill -INT -- -$p 2>/dev/null; done; sleep 2; for p in "${PIDS[@]}"; do kill -TERM -- -$p 2>/dev/null; done; }
trap 'stop_all' EXIT
has_topic() { ros2 topic list 2>/dev/null | grep -qx "$1"; }
sleep 2
has_topic /imu || start limo_base run_limo_base.sh
has_topic /camera/color/image_raw || start camera run_camera.sh
for i in $(seq 1 30); do has_topic /imu && has_topic /camera/color/image_raw && break; sleep 1; done
has_topic /imu || { echo "ERRO: sem /imu (veja $OUT/limo_base.log)"; exit 1; }
has_topic /camera/color/image_raw || { echo "ERRO: sem imagem (veja $OUT/camera.log; camera_probe.sh)"; exit 1; }
echo "Drivers OK. Iniciando $M..."
start method $RUN
sleep 6
start pose pose_logger.py --topic $POSE --type $TYPE --out $OUT/${N}_${M}.tum
start rt rt_monitor.py --name rt_${N}_${M} --pose-topic $POSE --pose-type $TYPE --proc $PROC --expected-hz $HZ --out-dir $OUT
start bag ros2 bag record -o $OUT/bag --max-cache-size 536870912 /camera/color/image_raw /imu /odom $POSE
sleep 4
echo ">>> Executando a rota '$R' a $V m/s (Ctrl+C para parar e zerar a velocidade)"
python3 /opt/limo_vio/tools/route_ros2.py $R $V
sleep 3
echo "Encerrando..."
stop_all; wait 2>/dev/null
trap - EXIT
echo; echo "==== RESULTADO ===="; tail -15 $OUT/rt.log
echo; echo "Poses gravadas:"; wc -l $OUT/${N}_${M}.tum
echo "Arquivos em $OUT. Proximo passo: evo_ape tum <ground_truth.tum> $OUT/${N}_${M}.tum -a (no PC)"
