#!/bin/bash
. /usr/local/bin/build_common.sh
n=okvis2; : > /opt/status/$n.log
mkdir -p /opt/okvis_ws/src && cd /opt/okvis_ws/src
git clone --recurse-submodules --branch ${OKVIS_REF:-main} https://github.com/ethz-mrl/okvis2.git okvis2 >> /opt/status/$n.log 2>&1 || { mark_fail $n clone; exit 0; }
git -C okvis2 log -1 --format='OKVIS2 commit: %H' | tee /opt/status/$n.commit
# Sem LibTorch, RealSense, apps de demonstracao nem testes
ws_build $n /opt/okvis_ws okvis -DBUILD_ROS2=ON -DUSE_NN=OFF -DHAVE_LIBREALSENSE=OFF -DBUILD_APPS=OFF -DBUILD_TESTS=OFF
exit 0
