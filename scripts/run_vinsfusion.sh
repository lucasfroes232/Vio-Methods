#!/bin/bash
# Dentro do container vinsfusion. Pose em /odometry (nav_msgs/Odometry, frame "world"), ~10 Hz (freq do YAML).
CFG=${CFG:-/opt/limo_vio/configs}
mkdir -p /data/results/vinsf_out
exec ros2 run vins vins_node $CFG/vinsf_limo.yaml
