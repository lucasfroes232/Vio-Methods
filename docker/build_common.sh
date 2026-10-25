#!/bin/bash
# Funcoes comuns. Cada metodo/driver e compilado isolado: se um falhar, os outros continuam e o
# resultado fica em /opt/status/<nome> (OK ou FAIL) com o log em /opt/status/<nome>.log.
mkdir -p /opt/status
src_ros() { set +u; source /opt/ros/${ROS_DISTRO}/setup.bash; }
# uso: ws_build <nome> <workspace> <pacotes> [args do cmake...]
ws_build() {
  local name=$1 ws=$2 pk=$3; shift 3
  src_ros
  ( cd $ws && MAKEFLAGS="-j3" colcon build --executor sequential --event-handlers console_cohesion+ \
      --packages-select $pk --cmake-args -DCMAKE_BUILD_TYPE=Release "$@" ) >> /opt/status/$name.log 2>&1
  if [ $? -eq 0 ]; then echo OK > /opt/status/$name; rm -rf $ws/build $ws/log
  else echo FAIL > /opt/status/$name; echo "=== FALHOU: $name (ultimas linhas do log)"; tail -60 /opt/status/$name.log; fi
}
mark_fail() { echo FAIL > /opt/status/$1; echo "=== FALHOU: $1 ($2)"; tail -40 /opt/status/$1.log 2>/dev/null; }
