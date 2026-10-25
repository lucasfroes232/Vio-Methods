#!/bin/bash
# Grava os sensores do Limo em ROS 2 (rodar no HOST do Limo, com os drivers ja rodando).
# Uso: record_run_ros2.sh <nome_da_sequencia> [duracao_em_segundos]
# Ex.:  record_run_ros2.sh teste_mao
# Saida: ~/vio_data/runs_ros2/<nome>_r<N>/  (pasta do bag ROS 2)  e  <nome>_r<N>.txt
# Nao divide o bag em arquivos (sem -b), para a conversao para ROS 1 ficar simples.
# Topicos: edite ~/vio_ws/scripts/vio.env (IMAGE_TOPIC, CAMINFO_TOPIC, IMU_TOPIC, EXTRA_TOPICS).

source /opt/ros/foxy/setup.bash
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/vio.env"

NAME="$1"
DUR="$2"
if [ -z "$NAME" ]; then
  echo "Uso: record_run_ros2.sh <nome_da_sequencia> [duracao_em_segundos]"
  exit 1
fi

OUT="$HOME/vio_data/runs_ros2"
mkdir -p "$OUT"
N=1
while [ -e "$OUT/${NAME}_r${N}" ]; do N=$((N+1)); done
BAG="$OUT/${NAME}_r${N}"

# 1) os topicos existem?
ros2 topic list > /tmp/topics_vio.txt 2>/dev/null
if [ ! -s /tmp/topics_vio.txt ]; then
  echo "ERRO: nenhum topico visivel. Os drivers estao rodando? O ROS_DOMAIN_ID e o mesmo?"
  exit 1
fi
TOPICS="$IMAGE_TOPIC $CAMINFO_TOPIC $IMU_TOPIC $EXTRA_TOPICS $POSE_TOPICS"   # POSE_TOPICS: pose(s) do metodo ao vivo, ex.: POSE_TOPICS="/ov_msckf/poseimu"
for T in $TOPICS; do
  if ! grep -qx "$T" /tmp/topics_vio.txt; then
    echo "ERRO: o topico $T nao existe. Confira vio.env e os drivers (ros2 topic list)."
    exit 1
  fi
done

# 2) espaco em disco
FREE_GB=$(df --output=avail -BG "$HOME" | tail -1 | tr -dc '0-9')
echo "Espaco livre: ${FREE_GB} GB"
if [ "${FREE_GB:-0}" -lt 5 ]; then
  echo "AVISO: menos de 5 GB livres. Libere espaco antes de gravar."
fi

echo
echo "Gravando em: $BAG"
echo "Roteiro: 2 s parado -> um giro rapido do robo -> 5 s de movimento suave -> trajeto -> 2 s parado."
read -r -p "Robo parado e pronto? Enter para iniciar (Ctrl+c cancela) " _

{
  echo "bag: $BAG"
  echo "inicio_iso: $(date --iso-8601=ns)"
  echo "inicio_unix: $(date +%s.%N)"
  echo "host: $(hostname)"
  echo "topicos: $TOPICS"
} > "$BAG.txt"

if [ -n "$DUR" ]; then
  timeout -s INT "$DUR" ros2 bag record --max-cache-size "${CACHE_BYTES:-536870912}" -o "$BAG" $TOPICS
else
  echo "Para parar a gravacao: Ctrl+c"
  ros2 bag record --max-cache-size "${CACHE_BYTES:-536870912}" -o "$BAG" $TOPICS
fi

echo "fim_iso: $(date --iso-8601=ns)" >> "$BAG.txt"
echo
ros2 bag info "$BAG"
echo
echo "CONFIRA acima: cada topico precisa ter 'Count' maior que 0."
echo "Se algum ficou com 0 mensagens, pode ser incompatibilidade de QoS no Foxy: me avise."
