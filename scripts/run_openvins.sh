#!/bin/bash
# Dentro do container. OpenVINS (ROS 2) em modo monocular + IMU.
# Topicos de saida (namespace ov_msckf): /ov_msckf/poseimu  /ov_msckf/odomimu  /ov_msckf/pathimu
CFG=${CFG:-/opt/limo_vio/configs}
exec ros2 launch ov_msckf subscribe.launch.py \
  config_path:=$CFG/ov/estimator_config.yaml max_cameras:=1 use_stereo:=false verbosity:=INFO
