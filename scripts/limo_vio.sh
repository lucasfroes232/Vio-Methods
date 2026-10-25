#!/bin/bash
# No HOST do Limo. Abre o container (rede do host, ver os topicos ROS 2 dos drivers).
# Uso: limo_vio.sh [comando...]      Ex.: limo_vio.sh run_openvins.sh
# Variaveis: IMAGE (padrao USUARIO/limo-vio:jazzy), ROS_DOMAIN_ID, RMW_IMPLEMENTATION
IMAGE=${IMAGE:-USUARIO/limo-vio:jazzy}
mkdir -p "$HOME/vio_data/results" "$HOME/vio_ws/configs"
EXTRA=()
# Se o host usa um arquivo de configuracao do Cyclone DDS, repassa ao container
if [[ "$CYCLONEDDS_URI" == file://* ]]; then
  f="${CYCLONEDDS_URI#file://}"
  [ -f "$f" ] && EXTRA=(-v "$f:$f:ro" -e "CYCLONEDDS_URI=$CYCLONEDDS_URI")
fi
# --privileged -v /dev:/dev: acesso a serial da base (/dev/ttyTHS1) e a camera (/dev/video*)
exec docker run --rm -it --name limo_vio --network host --privileged -v /dev:/dev \
  -e ROS_DOMAIN_ID="${ROS_DOMAIN_ID:-0}" \
  -e RMW_IMPLEMENTATION="${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}" \
  -v "$HOME/vio_data:/data" \
  -v "$HOME/vio_ws/configs:/configs" \
  "${EXTRA[@]}" "$IMAGE" "${@:-bash}"
