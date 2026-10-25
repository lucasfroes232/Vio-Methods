#!/bin/bash
source /opt/ros/${ROS_DISTRO}/setup.bash
for pair in limo_ws:limo_base ov_ws:openvins okvis_ws:okvis2 vins_ws:vinsfusion; do
  w=/opt/${pair%%:*}; n=${pair##*:}
  [ "$(cat /opt/status/$n 2>/dev/null)" = "OK" ] && [ -f $w/install/setup.bash ] && source $w/install/setup.bash
done
# imagens separadas (sem /opt/status): carrega o que existir
if [ ! -d /opt/status ]; then for w in /opt/limo_ws /opt/ov_ws /opt/okvis_ws /opt/vins_ws; do [ -f $w/install/setup.bash ] && source $w/install/setup.bash; done; fi
export RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}
exec "$@"
