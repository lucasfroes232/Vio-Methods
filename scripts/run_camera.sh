#!/bin/bash
# Imagem COLORIDA da Dabai como camera UVC padrao (V4L2), SEM o SDK da Orbbec (profundidade/IR nao usados).
# Publica /camera/color/image_raw (rgb8). O carimbo de tempo e o da CHEGADA do quadro (relogio do sistema,
# o mesmo da IMU); a latencia de captura fica para o td estimado pelo VINS / calibracao do OpenVINS.
# Variaveis: CAM_DEV (padrao /dev/video0), CAM_FMT (YUYV ou MJPG), CAM_FPS (padrao 30)
DEV=${CAM_DEV:-/dev/video0}
[ -e $DEV ] || { echo "ERRO: $DEV nao existe. Rode camera_probe.sh e ajuste CAM_DEV (e pare o driver da camera no host)."; exit 1; }
exec ros2 run v4l2_camera v4l2_camera_node --ros-args \
  -p video_device:=$DEV -p image_size:="[640,480]" -p pixel_format:=${CAM_FMT:-YUYV} \
  -p output_encoding:=rgb8 -p time_per_frame:="[1,${CAM_FPS:-30}]" \
  -p use_v4l2_buffer_timestamps:=false \
  -r image_raw:=/camera/color/image_raw -r camera_info:=/camera/color/camera_info
