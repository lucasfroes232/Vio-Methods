#!/bin/bash
# Driver da base do Limo (AgileX limo_ros2). Compila limo_msgs + limo_base.
. /usr/local/bin/build_common.sh
n=limo_base; : > /opt/status/$n.log
mkdir -p /opt/limo_ws/src && cd /opt/limo_ws/src
git clone --depth 1 --branch ${LIMO_REF:-humble} https://github.com/agilexrobotics/limo_ros2.git >> /opt/status/$n.log 2>&1 || \
git clone --depth 1 https://github.com/agilexrobotics/limo_ros2.git >> /opt/status/$n.log 2>&1 || { mark_fail $n clone; exit 0; }
git -C limo_ros2 log -1 --format='limo_ros2 commit: %H' | tee /opt/status/$n.commit
python3 /usr/local/bin/fix_includes.py /opt/limo_ws/src | tee -a /opt/status/$n.log
ws_build $n /opt/limo_ws "limo_msgs limo_base"
if [ "$(cat /opt/status/$n)" = "FAIL" ]; then
  # O codigo original usa declare_parameter(nome) sem valor padrao, que pode nao compilar em Jazzy.
  echo "=== tentando de novo com declare_parameter corrigido" | tee -a /opt/status/$n.log
  F=$(ls /opt/limo_ws/src/limo_ros2/limo_base/src/limo_driver.cpp)
  python3 - "$F" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p, encoding="utf-8").read()
d = {"port_name": '"ttyTHS1"', "odom_frame": '"odom"', "base_frame": '"base_link"',
     "pub_odom_tf": "false", "use_mcnamu": "false", "control_rate": "50"}
for k, v in d.items():
    s = s.replace('this->declare_parameter("%s");' % k,
                  'this->declare_parameter("%s", rclcpp::ParameterValue(%s), limo_pd);' % (k, v))
s = s.replace('this->declare_parameter("port_name", rclcpp::ParameterValue',
              'rcl_interfaces::msg::ParameterDescriptor limo_pd; limo_pd.dynamic_typing = true;\n    this->declare_parameter("port_name", rclcpp::ParameterValue', 1)
open(p, "w", encoding="utf-8").write(s)
PY
  rm -rf /opt/limo_ws/build /opt/limo_ws/install /opt/limo_ws/log
  ws_build $n /opt/limo_ws "limo_msgs limo_base"
fi
exit 0
