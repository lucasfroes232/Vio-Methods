#!/bin/bash
source /opt/ros/${ROS_DISTRO}/setup.bash
for w in /opt/limo_ws /opt/ov_ws /opt/okvis_ws /opt/vins_ws; do [ -f $w/install/setup.bash ] && source $w/install/setup.bash; done
export RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}
exec "$@"
