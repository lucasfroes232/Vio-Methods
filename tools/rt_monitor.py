#!/usr/bin/env python3
"""Evidencia de TEMPO REAL: roda ao lado do metodo (no mesmo container) e mede, a cada segundo,
taxa de entrada (imagem), taxa de saida (pose), latencia (agora - stamp da pose), CPU e RAM do metodo.
Ao dar Ctrl+C imprime um resumo e grava um CSV em /data/results/rt/.

Uso (OpenVINS):
  rt_monitor.py --name ov_reta --pose-topic /ov_msckf/poseimu --pose-type posecov \
                --proc ov_msckf --expected-hz 20
Uso (OKVIS2, mono+IMU, apos run_okvis2.sh):
  rt_monitor.py --name okvis_reta --pose-topic /okvis/okvis_odometry --pose-type odom --proc okvis_node --expected-hz 15

Criterio do veredito (AJUSTAVEL, e escolha nossa, nao um padrao): taxa de pose >= 90% da esperada
e latencia p95 <= --max-latency (padrao 0,25 s). A latencia usa o relogio do proprio Limo
(camera e metodo estao na mesma maquina), entao nao precisa de sincronizacao externa.
"""
import argparse, csv, os, signal, statistics, time
import psutil
import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
from sensor_msgs.msg import Image
from nav_msgs.msg import Odometry
from geometry_msgs.msg import PoseWithCovarianceStamped, PoseStamped

POSE_TYPES = {"odom": Odometry, "posecov": PoseWithCovarianceStamped, "posestamped": PoseStamped}


def percentile(v, q):
    if not v:
        return float("nan")
    v = sorted(v)
    return v[min(len(v) - 1, int(round(q * (len(v) - 1))))]


def summarize(rows, lat_all, n_img, n_pose, expected_hz, max_latency):
    dur = rows[-1]["t"] - rows[0]["t"] + 1.0 if rows else 0.0
    pose_hz = n_pose / dur if dur else 0.0
    img_hz = n_img / dur if dur else 0.0
    p95 = percentile(lat_all, 0.95)
    cpu = [r["cpu_method"] for r in rows]
    rss = [r["rss_mb"] for r in rows]
    ok = (pose_hz >= 0.9 * expected_hz) and (p95 <= max_latency)
    return {
        "duracao_s": dur, "imagens": n_img, "img_hz": img_hz, "poses": n_pose, "pose_hz": pose_hz,
        "pose_hz_esperado": expected_hz,
        "lat_media_s": statistics.mean(lat_all) if lat_all else float("nan"),
        "lat_p95_s": p95, "lat_max_s": max(lat_all) if lat_all else float("nan"),
        "cpu_medio_%": statistics.mean(cpu) if cpu else float("nan"), "cpu_max_%": max(cpu) if cpu else float("nan"),
        "ram_max_MB": max(rss) if rss else float("nan"),
        "veredito": "ACOMPANHA O TEMPO REAL" if ok else "NAO acompanha (ou nao inicializou)",
    }


class Mon(Node):
    def __init__(self, a):
        super().__init__("rt_monitor")
        qos = QoSProfile(reliability=ReliabilityPolicy.BEST_EFFORT, history=HistoryPolicy.KEEP_LAST, depth=10)
        self.n_img = self.n_pose = 0
        self.w_img = self.w_pose = 0
        self.w_lat = []
        self.lat_all = []
        self.create_subscription(Image, a.img_topic, self.on_img, qos)
        self.create_subscription(POSE_TYPES[a.pose_type], a.pose_topic, self.on_pose, qos)
        self.pose_type = a.pose_type

    def on_img(self, m):
        self.n_img += 1; self.w_img += 1

    def on_pose(self, m):
        st = m.header.stamp
        lat = time.time() - (st.sec + st.nanosec * 1e-9)
        self.n_pose += 1; self.w_pose += 1
        self.w_lat.append(lat); self.lat_all.append(lat)


def find_procs(pattern):
    out = []
    for p in psutil.process_iter(["name", "cmdline"]):
        try:
            if pattern in (p.info["name"] or "") or pattern in " ".join(p.info["cmdline"] or []):
                out.append(p)
        except psutil.Error:
            pass
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--img-topic", default="/camera/color/image_raw")
    ap.add_argument("--pose-topic", required=True)
    ap.add_argument("--pose-type", choices=list(POSE_TYPES), default="odom")
    ap.add_argument("--proc", required=True, help="trecho do nome do processo do metodo (ov_msckf, run_subscribe_msckf, okvis_node_subscriber...)")
    ap.add_argument("--expected-hz", type=float, required=True)
    ap.add_argument("--max-latency", type=float, default=0.25)
    ap.add_argument("--out-dir", default="/data/results/rt")
    a = ap.parse_args()
    signal.signal(signal.SIGTERM, signal.default_int_handler)
    signal.signal(signal.SIGINT, signal.default_int_handler)
    os.makedirs(a.out_dir, exist_ok=True)
    rclpy.init()
    node = Mon(a)
    procs = {}
    rows = []
    t0 = time.time(); next_t = t0 + 1.0
    psutil.cpu_percent(None)
    print("Monitorando... Ctrl+C para encerrar e ver o resumo.")
    try:
        while rclpy.ok():
            rclpy.spin_once(node, timeout_sec=0.05)
            now = time.time()
            if now < next_t:
                continue
            for p in find_procs(a.proc):
                procs.setdefault(p.pid, p)
            cpu = rss = 0.0
            for pid, p in list(procs.items()):
                try:
                    cpu += p.cpu_percent(None); rss += p.memory_info().rss / 1e6
                except psutil.Error:
                    procs.pop(pid, None)
            lat = node.w_lat
            row = {"t": now - t0, "img_hz": node.w_img, "pose_hz": node.w_pose,
                   "lat_mean_s": statistics.mean(lat) if lat else float("nan"),
                   "lat_max_s": max(lat) if lat else float("nan"),
                   "cpu_method": cpu, "cpu_sys": psutil.cpu_percent(None), "rss_mb": rss}
            rows.append(row)
            print("t=%5.0fs  img %2d Hz  pose %2d Hz  lat %.3f s  cpu_metodo %5.0f%%  cpu_sys %3.0f%%  ram %4.0f MB" % (
                row["t"], row["img_hz"], row["pose_hz"], row["lat_mean_s"], cpu, row["cpu_sys"], rss))
            node.w_img = node.w_pose = 0; node.w_lat = []
            next_t += 1.0
    except KeyboardInterrupt:
        pass
    path = os.path.join(a.out_dir, a.name + ".csv")
    if rows:
        with open(path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    s = summarize(rows, node.lat_all, node.n_img, node.n_pose, a.expected_hz, a.max_latency)
    print("\n==== RESUMO ====")
    for k, v in s.items():
        print("%-18s %s" % (k, ("%.3f" % v) if isinstance(v, float) else v))
    print("CSV:", path)
    node.destroy_node(); rclpy.shutdown()


if __name__ == "__main__":
    main()
