#!/usr/bin/env python3
# Rota simples para o Limo via /cmd_vel (ROS 2 Foxy). Roda no host.
# Uso: python3 route_ros2.py reta|quadrado|oito|oval [velocidade_m_s] [lado_m] [raio_curva_m]
#   reta     : 2,0 m em linha reta, COM CORRECAO DE RUMO em malha fechada (giroscopio da /imu)
#              e parada pela distancia da /odom. Nao faz curvas.
#   quadrado : lado de 1,0 m (padrao) com cantos em arco de 0,5 m -> ocupa ~2,0 x 2,0 m, ~36 s (malha aberta)
# Quadrado/oito/oval sao em malha aberta: o trajeto real sai diferente do desenhado, por isso o Vicon.
# CUIDADO: area livre; mantenha o controle manual a mao (Ctrl+c para e zera a velocidade).
import sys, time, math

KP, KI, WMAX = 2.0, 0.3, 0.3      # controle PI de rumo da reta
RETA_M = 2.0


def heading_pi(yaw, integ, kp=KP, ki=KI, wmax=WMAX):
    """Comando angular que leva o rumo (yaw, rad, 0 = direcao inicial) de volta a zero."""
    w = -(kp * yaw + ki * integ)
    return max(-wmax, min(wmax, w))


def run_reta(rclpy, node, pub, v):
    from sensor_msgs.msg import Imu
    from nav_msgs.msg import Odometry
    from geometry_msgs.msg import Twist
    st = {"gz": None, "t_gz": None, "x": None, "y": None}

    def on_imu(m):
        st["gz"] = m.angular_velocity.z
        st["t_imu"] = time.time()

    def on_odom(m):
        st["x"], st["y"] = m.pose.pose.position.x, m.pose.pose.position.y

    node.create_subscription(Imu, "/imu", on_imu, 50)
    node.create_subscription(Odometry, "/odom", on_odom, 10)
    t0 = time.time()
    while (st["gz"] is None or st["x"] is None) and time.time() - t0 < 5:
        rclpy.spin_once(node, timeout_sec=0.1)
    if st["gz"] is None or st["x"] is None:
        print("ERRO: sem /imu ou /odom. A base esta no ar? O robo NAO se moveu.")
        return
    x0, y0 = st["x"], st["y"]
    yaw = integ = 0.0
    dt = 0.05
    t_last = time.time()
    t_max = 2.5 * RETA_M / v
    t_start = time.time()
    print(f"Reta de {RETA_M} m a {v} m/s com correcao de rumo. Ctrl+c para.")
    while time.time() - t_start < t_max:
        rclpy.spin_once(node, timeout_sec=dt)
        now = time.time()
        h = now - t_last
        t_last = now
        yaw += (st["gz"] or 0.0) * h          # rumo integrado do giroscopio (0 = direcao de partida)
        integ += yaw * h
        dist = math.hypot(st["x"] - x0, st["y"] - y0)
        if dist >= RETA_M:
            break
        m = Twist(); m.linear.x = float(v); m.angular.z = float(heading_pi(yaw, integ))
        pub.publish(m)
    print(f"Fim: distancia {dist:.2f} m (odom), rumo final {math.degrees(yaw):.1f} graus")


def main():
    import rclpy
    from geometry_msgs.msg import Twist
    shape = sys.argv[1] if len(sys.argv) > 1 else "oval"
    v = min(float(sys.argv[2]) if len(sys.argv) > 2 else 0.2, 0.4)
    rclpy.init(); n = rclpy.create_node("route_ros2")
    pub = n.create_publisher(Twist, "/cmd_vel", 10)
    try:
        if shape == "reta":
            run_reta(rclpy, n, pub, v)
        else:
            lado = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
            raio = float(sys.argv[4]) if len(sys.argv) > 4 else 0.5
            w = v / raio
            t_circ = 2 * math.pi / w
            t_quarter = (math.pi / 2) / w
            side = lado / v
            if shape == "quadrado": seg = [(v, 0, side), (v, w, t_quarter)] * 4
            elif shape == "oito":   seg = [(v, w, t_circ), (v, -w, t_circ)]
            else:                   seg = [(v, 0, side), (v, w, t_circ / 2), (v, 0, side), (v, w, t_circ / 2)]
            for lin, ang, dur in seg:
                m = Twist(); m.linear.x = float(lin); m.angular.z = float(ang)
                t0 = time.time()
                while time.time() - t0 < dur:
                    pub.publish(m); time.sleep(0.05)
    except KeyboardInterrupt:
        pass
    finally:
        for _ in range(40):                      # ~2 s parado no fim
            pub.publish(Twist()); time.sleep(0.05)
        n.destroy_node(); rclpy.shutdown()


if __name__ == "__main__":
    main()
