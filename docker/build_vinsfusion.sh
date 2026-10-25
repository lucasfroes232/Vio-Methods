#!/bin/bash
. /usr/local/bin/build_common.sh
n=vinsfusion; : > /opt/status/$n.log
CERES_ARGS=()
# Ceres 2.1.0 (versao em que a porta foi testada) em prefixo proprio, sem conflitar com o libceres-dev do apt (OpenVINS)
if git clone --depth 1 --branch ${CERES_REF:-2.1.0} https://github.com/ceres-solver/ceres-solver.git /tmp/ceres >> /opt/status/$n.log 2>&1 \
   && cmake -S /tmp/ceres -B /tmp/ceres/build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/ceres-2.1 \
        -DBUILD_TESTING=OFF -DBUILD_EXAMPLES=OFF -DBUILD_BENCHMARKS=OFF >> /opt/status/$n.log 2>&1 \
   && cmake --build /tmp/ceres/build -j3 >> /opt/status/$n.log 2>&1 && cmake --install /tmp/ceres/build >> /opt/status/$n.log 2>&1; then
  CERES_ARGS=(-DCeres_DIR=/opt/ceres-2.1/lib/cmake/Ceres); echo "Ceres 2.1.0 compilado" >> /opt/status/$n.log
else
  echo "AVISO: Ceres 2.1.0 falhou; usando o Ceres do apt" | tee -a /opt/status/$n.log
fi
rm -rf /tmp/ceres
mkdir -p /opt/vins_ws/src && cd /opt/vins_ws/src
git clone ${VINSF_REPO:-https://github.com/the-ninth-moon/VINS-Fusion-ROS2-humble-arm.git} VINS-Fusion-ROS2 >> /opt/status/$n.log 2>&1 || { mark_fail $n clone; exit 0; }
cd VINS-Fusion-ROS2 && git checkout ${VINSF_REF:-master} >> /opt/status/$n.log 2>&1
git log -1 --format='VINSF commit: %H' | tee /opt/status/$n.commit
# CPU apenas (OpenCV do apt sem CUDA): desliga o macro de GPU
F=vins/src/featureTracker/feature_tracker.h
sed -i 's|^#define GPU_MODE 1|// #define GPU_MODE 1|' $F && grep -q '^// #define GPU_MODE 1' $F || { mark_fail $n "macro GPU_MODE nao encontrada"; exit 0; }
ws_build $n /opt/vins_ws "camera_models vins" "${CERES_ARGS[@]}"
exit 0
