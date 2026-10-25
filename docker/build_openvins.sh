#!/bin/bash
. /usr/local/bin/build_common.sh
n=openvins; : > /opt/status/$n.log
mkdir -p /opt/ov_ws/src && cd /opt/ov_ws/src
git clone --depth 1 --branch ${OV_REF:-master} https://github.com/rpng/open_vins.git >> /opt/status/$n.log 2>&1 || { mark_fail $n clone; exit 0; }
git -C open_vins log -1 --format='OpenVINS commit: %H' | tee /opt/status/$n.commit
python3 /usr/local/bin/fix_includes.py /opt/ov_ws/src | tee -a /opt/status/$n.log
ws_build $n /opt/ov_ws "ov_core ov_init ov_msckf"
exit 0
