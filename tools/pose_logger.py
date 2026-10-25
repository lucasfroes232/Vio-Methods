#!/usr/bin/env python3
"""Grava em TEMPO REAL a pose que o metodo publica, em formato TUM (t x y z qx qy qz qw), pronto para o evo.
Uso: pose_logger.py --topic /ov_msckf/poseimu --type posecov --out saida.tum
"""
import argparse, signal


def pose_line(msg, kind):
    """-> 't x y z qx qy qz qw' (stamp do header, em segundos)."""
    st = msg.header.stamp
    p = msg.pose if kind == "posestamped" else msg.pose.pose
    pos, q = p.position, p.orientation
    return "%.9f %.9f %.9f %.9f %.9f %.9f %.9f %.9f" % (
        st.sec + st.nanosec * 1e-9, pos.x, pos.y, pos.z, q.x, q.y, q.z, q.w)


def main():
    import rclpy
    from rclpy.node import Node
    from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
    from nav_msgs.msg import Odometry
    from geometry_msgs.msg import PoseWithCovarianceStamped, PoseStamped
    types = {"odom": Odometry, "posecov": PoseWithCovarianceStamped, "posestamped": PoseStamped}
    ap = argparse.ArgumentParser()
    ap.add_argument("--topic", required=True)
    ap.add_argument("--type", choices=list(types), default="odom")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    signal.signal(signal.SIGINT, signal.default_int_handler)
    rclpy.init()
    node = Node("pose_logger")
    f = open(a.out, "w", buffering=1)
    n = [0]

    def cb(m):
        f.write(pose_line(m, a.type) + "\n"); n[0] += 1

    # best-effort aceita publicadores reliable e best-effort
    qos = QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT, history=HistoryPolicy.KEEP_LAST, depth=100)
    node.create_subscription(types[a.type], a.topic, cb, qos)
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    f.close()
    print("pose_logger: %d poses em %s" % (n[0], a.out))


if __name__ == "__main__":
    main()
