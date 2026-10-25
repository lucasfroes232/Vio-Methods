# limo-vio — metodos VIO em ROS 2 + drivers do Limo (ARM64), prontos para `docker pull`

**Imagem principal: `:jazzy`** (`Dockerfile.all`, ROS 2 Jazzy). Um container com OpenVINS, OKVIS2, VINS-Fusion, driver da base
(`limo_base`), camera (V4L2) e as ferramentas de experimento. Cada componente e compilado isolado: se um falhar o resto continua e
`status.sh` mostra quem compilou. As imagens `:openvins`, `:okvis2` e `:vinsfusion` (Dockerfiles separados, Humble/Jazzy) ficam como **plano B**.
Objetivo geral e plano da pesquisa: veja `OBJETIVO.md`.

## Rodar um experimento (dentro do container, no Limo)
```
docker pull SEU_USUARIO/limo-vio:jazzy
./limo_vio.sh                      # scripts/limo_vio.sh; abre o container (--privileged, --network host)
status.sh                          # quem compilou
camera_probe.sh                    # achar o /dev/videoN colorido da Dabai (se nao for o /dev/video0: export CAM_DEV=/dev/videoN)
run_experiment.sh openvins reta teste01 0.2      # tambem: okvis2 | vinsfusion ; rotas: reta quadrado oito oval
```
`run_experiment.sh` sobe `limo_base` e a camera (se ainda nao houver `/imu` e `/camera/color/image_raw`), inicia o metodo, grava em
`/data/results/<nome>/` (= `~/vio_data/results/<nome>/` no Limo): a pose do metodo em tempo real em **TUM** (`.tum`), o bag
(imagem, IMU, /odom, pose), as metricas de tempo real (`rt_*.csv` + resumo) e os logs; depois roda a rota e encerra tudo.
**Pare os drivers antigos do host** (Foxy) antes, ou deixe-os: o script so sobe os que faltarem. O robo ANDA: area livre e controle a mao.

Comparar com a Vicon (no PC): `evo_ape tum ground_truth.tum <nome>_<metodo>.tum -a` (e `evo_rpe`).

## Como publicar (uma vez) — GitHub Actions + Docker Hub
1. Docker Hub: repositorio `limo-vio` e *Access Token* Read & Write. **Nunca cole o token em conversa, arquivo ou codigo.**
2. GitHub: repositorio **publico** (runner ARM64 gratis) com estes arquivos (inclua a pasta oculta `.github/`).
3. Settings > Secrets and variables > Actions: `DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN`.
4. Actions > build-limo-vio > Run workflow. Os jobs rodam em paralelo (a imagem `:jazzy` deve levar 2 a 4 h; limite de 6 h do GitHub).
   No log do job `jazzy`, procure as linhas `limo_base: OK/FAIL`, `openvins: ...` etc.

## O que e incerto (NADA foi compilado ou rodado)
- **Jazzy (Ubuntu 24.04)**: so o OKVIS2 documenta Jazzy. OpenVINS (Dockerfiles ROS 2 para 18.04/20.04/22.04) e a porta do VINS-Fusion (Humble) nao foram verificados em 24.04/GCC 13; podem exigir ajuste, e e por isso que cada um compila isolado.
- **limo_base**: o codigo oficial e da branch `humble`; usa `declare_parameter(nome)` sem valor padrao, que pode nao compilar em Jazzy. O build tenta, e se falhar aplica uma correcao automatica e tenta de novo.
- **Camera**: SUBSTITUI o driver Orbbec do host por V4L2 (`v4l2_camera`), usando a Dabai como camera UVC (o README do driver Orbbec diz que a Dabai usa UVC). Nao foi testado: o `/dev/videoN` correto e o formato (YUYV ou MJPG a 640x480) precisam ser confirmados com `camera_probe.sh`. O carimbo de tempo e o da chegada do quadro (ha um atraso de captura de alguns ms a dezenas de ms): o VINS-Fusion estima isso (`estimate_td`), no OpenVINS e no OKVIS2 fica como erro.
  Se nao funcionar: mantenha o driver Orbbec no host (Foxy) e rode so os metodos no container (`--network host`); `run_experiment.sh` ja pula o que existir.
- **OKVIS2 mono**: README dos autores nao descreve mono; a imagem exige mono8 e `okvis_relay.py` converte (conversao testada com dados sinteticos).
- **VINS-Fusion**: porta de terceiros; so estereo+IMU documentado; Ceres 2.1.0 compilado do codigo-fonte (se falhar, usa o do apt).
- **Topicos de pose** (`/ov_msckf/poseimu`, `/okvis/okvis_odometry`, `/odometry`) vem do codigo; confirme com `ros2 topic list`.
- **DDS**: host Foxy x container Jazzy (Cyclone DDS, `--network host`). Confirme com `ros2 topic list` e `ros2 topic hz /imu`.
- **Parametros**: intrinsecas de fabrica, extrinseca com translacao chutada, ruidos conservadores; troque pelos do Kalibr.
- Criterio de tempo real (pose >= 90% da esperada e latencia p95 <= 0,25 s) e escolha nossa.

---
(Documentacao anterior, das imagens separadas)

| Tag | Metodo | Base | Por que esta aqui |
|---|---|---|---|
| `:openvins` | OpenVINS (mono + IMU) | ROS 2 Humble | ROS 2 oficial dos autores (CI e Dockerfiles ROS 2 no repositorio) |
| `:okvis2` | OKVIS2 (mono + IMU, VIO puro) | ROS 2 Jazzy | ROS 2 oficial dos autores (`BUILD_ROS2`, nos `okvis_node_*`) |
| `:vinsfusion` | VINS-Fusion mono + IMU (sucessor do VINS-Mono) | ROS 2 Humble | **porta da comunidade** (the-ninth-moon), NAO oficial; autor relata testes em Jetson Orin/Nano, mas documenta so estereo+IMU |

VINS-Mono nao tem ROS 2 (o VINS-Fusion e o sucessor dele, com o mesmo nucleo, e e o que esta aqui, por porta de terceiros). Descartados por **nao terem ROS 2**: ORB-SLAM3 mono-inercial, ROVIO (port em andamento, so fork pessoal).

**Nada aqui foi compilado ou rodado ainda.** O primeiro build no GitHub Actions e o primeiro teste.

## 1. Publicar (uma vez) — GitHub Actions + Docker Hub
1. Docker Hub: crie o repositorio `limo-vio` e um *Access Token* Read & Write (Account Settings > Security). **Nunca cole o token em conversa, arquivo ou codigo.**
2. GitHub: crie um repositorio **publico** e suba estes arquivos (incluindo a pasta oculta `.github/`).
3. Settings > Secrets and variables > Actions > New secret: `DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN`.
4. Actions > build-limo-vio > Run workflow. Os dois jobs rodam em paralelo (1 a 3 h). Se um falhar, o outro continua publicado.

## 2. Usar no Limo
```
docker pull SEU_USUARIO/limo-vio:openvins      # e/ou :okvis2
export IMAGE=SEU_USUARIO/limo-vio:openvins
./limo_vio.sh                                  # (scripts/limo_vio.sh) abre o container com --network host
```
No host: base + camera no ar (camera com `enable_depth:=false enable_ir:=false enable_point_cloud:=false`).
Dentro do container, `ros2 topic list` deve mostrar `/camera/color/image_raw` e `/imu`.

**OpenVINS**
```
run_openvins.sh                                                                  # terminal 1
rt_monitor.py --name ov_teste --pose-topic /ov_msckf/poseimu --pose-type posecov --proc ov_msckf --expected-hz 20   # terminal 2 (docker exec -it limo_vio bash)
```
**OKVIS2** (`IMAGE=SEU_USUARIO/limo-vio:okvis2 ./limo_vio.sh`)
```
run_okvis2.sh                                                                    # ponte de topicos + OKVIS2
rt_monitor.py --name okvis_teste --pose-topic /okvis/okvis_odometry --pose-type odom --proc okvis_node --expected-hz 15
```
**VINS-Fusion** (`IMAGE=SEU_USUARIO/limo-vio:vinsfusion ./limo_vio.sh`)
```
run_vinsfusion.sh
rt_monitor.py --name vinsf_teste --pose-topic /odometry --pose-type odom --proc vins_node --expected-hz 10
```
Prova adicional: `tegrastats` no host durante a execucao.

## 3. Gravar para comparar com a Vicon (tudo em ROS 2)
No host: `POSE_TOPICS="/ov_msckf/poseimu" ./record_run_ros2.sh nome` (ou `/okvis/okvis_odometry`) grava imagem, IMU, /odom e a pose do metodo no mesmo bag. Depois `evo_traj bag2 <bag> /ov_msckf/poseimu --save_as_tum`.

## O que ainda e incerto (nao verificado)
- **Compilacao** das tres imagens (nenhuma foi construida). O OKVIS2 compila ceres, brisk, DBoW2 e opengv dos submodulos; tempo/memoria no runner desconhecidos.
- **OKVIS2 mono**: o README dos autores nao descreve o modo mono. O no cria um assinante por camera do YAML (`numCameras`), entao 1 camera e suportada pelo desenho, mas nao foi testada. Se nao inicializar, e o primeiro suspeito.
- **OKVIS2 le imagem so em mono8** (verificado em `Subscriber.cpp`); por isso `okvis_relay.py` converte (a conversao foi testada com dados sinteticos, o no ROS nao).
- **Nome do topico de pose do OKVIS2** (`/okvis/okvis_odometry`) deduzido do codigo; confirme com `ros2 topic list | grep okvis`.
- **QoS/DDS**: host Foxy; containers Humble/Jazzy com Cyclone DDS e `--network host`. Confirme com `ros2 topic list` e `ros2 topic hz /imu` dentro do container.
- **Parametros**: intrinsecas de fabrica, extrinseca com translacao chutada, ruidos conservadores. Troque pelos do Kalibr para a comparacao final.
- O criterio do veredito de tempo real (pose >= 90% da esperada e latencia p95 <= 0,25 s) e escolha nossa, ajuste se quiser.
- **VINS-Fusion (porta de terceiros)**: o repositorio traz um YAML de exemplo mono+IMU (EuRoC), mas o autor so documenta estereo+IMU. Na ARM ele relata `multiple_thread: 0` (ja no YAML) e `-DEIGEN_DONT_VECTORIZE` (ja nos CMakeLists dele). Aqui o Ceres 2.1.0 e compilado do codigo-fonte (versao em que ele testou), o OpenCV e o 4.5 do apt (ele usa 4.10 com CUDA) e a GPU fica desligada. Se o build falhar, o log mostra onde.
- O topico de pose `/odometry` vem do codigo (`visualization.cpp`, nome relativo, no sem namespace); confirme com `ros2 topic list`.
