#!/bin/bash
# Mostra as cameras V4L2 e os formatos de cada /dev/video* (para achar a imagem colorida da Dabai).
v4l2-ctl --list-devices
for d in /dev/video*; do echo "=== $d"; v4l2-ctl -d $d --list-formats-ext 2>/dev/null | head -30; done
