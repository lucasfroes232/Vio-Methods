#!/bin/bash
# Dentro do container okvis2. Sobe a ponte de topicos e o OKVIS2 (sem rviz).
CFG=${CFG:-/opt/limo_vio/configs}
IMG=${IMG_TOPIC:-/camera/color/image_raw}
IMU=${IMU_TOPIC:-/imu}
python3 /opt/limo_vio/tools/okvis_relay.py "$IMG" "$IMU" &
RELAY=$!
trap 'kill $RELAY 2>/dev/null' EXIT
# pose publicada em /okvis/okvis_odometry (nav_msgs/Odometry); confirme com: ros2 topic list | grep okvis
ros2 launch okvis okvis_node_subscriber.launch.xml config_filename:=$CFG/okvis2_limo.yaml rviz:=false
