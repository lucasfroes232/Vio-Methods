#!/usr/bin/env python3
"""Ponte de topicos para o OKVIS2 (necessaria, verificado no codigo dele):
 - O Subscriber do OKVIS2 le a imagem como CV_8UC1 sem converter -> precisa de mono8.
   A camera do Limo publica rgb8/bgr8, entao convertemos aqui.
 - Os nomes sao fixos: /okvis/cam0/image_raw e /okvis/imu0.
 O timestamp original e preservado (a latencia medida continua valida).
"""
import sys
import numpy as np
import cv2


def to_mono8(data, height, width, step, encoding):
    """bytes + geometria -> matriz uint8 HxW em cinza. Respeita 'step' (padding de linha)."""
    enc = encoding.lower()
    buf = np.frombuffer(data, dtype=np.uint8)
    if enc in ("mono8", "8uc1"):
        return buf.reshape(height, step)[:, :width].copy()
    if enc in ("rgb8", "bgr8"):
        img = buf.reshape(height, step)[:, : width * 3].reshape(height, width, 3)
        code = cv2.COLOR_RGB2GRAY if enc == "rgb8" else cv2.COLOR_BGR2GRAY
        return cv2.cvtColor(img, code)
    if enc in ("rgba8", "bgra8"):
        img = buf.reshape(height, step)[:, : width * 4].reshape(height, width, 4)
        code = cv2.COLOR_RGBA2GRAY if enc == "rgba8" else cv2.COLOR_BGRA2GRAY
        return cv2.cvtColor(img, code)
    raise ValueError("encoding nao suportado: " + encoding)


def main():
    import rclpy
    from rclpy.node import Node
    from rclpy.qos import qos_profile_sensor_data
    from sensor_msgs.msg import Image, Imu

    img_in = sys.argv[1] if len(sys.argv) > 1 else "/camera/color/image_raw"
    imu_in = sys.argv[2] if len(sys.argv) > 2 else "/imu"

    class Relay(Node):
        def __init__(self):
            super().__init__("okvis_relay")
            # entrada best-effort: aceita publicadores reliable ou best-effort
            self.pi = self.create_publisher(Image, "/okvis/cam0/image_raw", 10)
            self.pm = self.create_publisher(Imu, "/okvis/imu0", 1000)
            self.create_subscription(Image, img_in, self.on_img, qos_profile_sensor_data)
            self.create_subscription(Imu, imu_in, self.pm.publish, qos_profile_sensor_data)
            self.n = 0

        def on_img(self, m):
            g = to_mono8(bytes(m.data), m.height, m.width, m.step, m.encoding)
            o = Image()
            o.header = m.header
            o.height, o.width, o.encoding = m.height, m.width, "mono8"
            o.is_bigendian, o.step = 0, m.width
            o.data = g.tobytes()
            self.pi.publish(o)

    rclpy.init()
    rclpy.spin(Relay())


if __name__ == "__main__":
    main()
