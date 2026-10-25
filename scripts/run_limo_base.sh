#!/bin/bash
# Driver da base do Limo (publica /odom, /imu, /limo_status; recebe /cmd_vel). Precisa de acesso a /dev/ttyTHS1.
PORT=${LIMO_PORT:-ttyTHS1}
[ -e /dev/$PORT ] || echo "AVISO: /dev/$PORT nao existe aqui. Abra o container com limo_vio.sh (usa --privileged -v /dev:/dev)."
exec ros2 launch limo_base limo_base.launch.py port_name:=$PORT
