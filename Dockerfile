# --build-arg ENV={standard|dmlab|minerl}
ARG ENV=standard
# --build-arg TYPE={full|base}
ARG TYPE=full

FROM pytorch/pytorch:1.11.0-cuda11.3-cudnn8-devel AS base

# System packages for Atari, DMLab, MiniWorld... Throw in everything
RUN apt-get update && apt-get install -y \
    git xvfb \
    libglu1-mesa libglu1-mesa-dev libgl1-mesa-dev libosmesa6-dev mesa-utils freeglut3 freeglut3-dev \
    libglew2.0 libglfw3 libglfw3-dev zlib1g zlib1g-dev libsdl2-dev libjpeg-dev lua5.1 liblua5.1-0-dev libffi-dev \
    build-essential cmake g++-4.8 pkg-config software-properties-common gettext \
    ffmpeg patchelf swig unrar unzip zip curl wget tmux \
    && rm -rf /var/lib/apt/lists/*

# ------------------------
# Standard environments
# ------------------------

FROM base AS standard-env

# Atari

RUN pip3 install atari-py==0.2.9
RUN wget -L -nv http://www.atarimania.com/roms/Roms.rar && \
    unrar x Roms.rar && \
    python3 -m atari_py.import_roms ROMS && \
    rm -rf Roms.rar ROMS.zip ROMS

# DMC MuJoCo

RUN mkdir -p /root/.mujoco && \
    cd /root/.mujoco && \
    wget -nv https://mujoco.org/download/mujoco210-linux-x86_64.tar.gz -O mujoco.tar.gz && \
    tar -xf mujoco.tar.gz && \
    rm mujoco.tar.gz
RUN pip3 install dm_control

# ------------------------
# DMLab (optional)
# ------------------------

# adapted from https://github.com/google-research/seed_rl
FROM base AS dmlab-env
# RUN echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | \
#     tee /etc/apt/sources.list.d/bazel.list && \
#     curl https://bazel.build/bazel-release.pub.gpg | \
#     apt-key add - && \
#     apt-get update && apt-get install -y bazel
# RUN git clone https://github.com/deepmind/lab.git /dmlab
# WORKDIR /dmlab
# RUN git checkout "937d53eecf7b46fbfc56c62e8fc2257862b907f2"
# RUN ln -s '/opt/conda/lib/python3.7/site-packages/numpy/core/include/numpy' /usr/include/numpy && \
#     sed -i 's@python3.5@python3.7@g' python.BUILD && \
#     sed -i 's@glob(\[@glob(["include/numpy/\*\*/*.h", @g' python.BUILD && \
#     sed -i 's@: \[@: ["include/numpy", @g' python.BUILD && \
#     sed -i 's@650250979303a649e21f87b5ccd02672af1ea6954b911342ea491f351ceb7122@682aee469c3ca857c4c38c37a6edadbfca4b04d42e56613b11590ec6aa4a278d@g' WORKSPACE && \
#     sed -i 's@rules_cc-master@rules_cc-main@g' WORKSPACE && \
#     sed -i 's@rules_cc/archive/master@rules_cc/archive/main@g' WORKSPACE && \
#     bazel build -c opt python/pip_package:build_pip_package --incompatible_remove_legacy_whole_archive=0
# RUN pip3 install wheel && \
#     PYTHON_BIN_PATH=$(which python3) && \
#     ./bazel-bin/python/pip_package/build_pip_package /tmp/dmlab_pkg && \
#     pip3 install /tmp/dmlab_pkg/DeepMind_Lab-*.whl --force-reinstall && \
#     rm -rf /dmlab
# WORKDIR /app
# COPY scripts/dmlab_data_download.sh .
# RUN sh dmlab_data_download.sh
ENV DMLAB_DATASET_PATH "/app/dmlab_data"

# ------------------------
# MineRL (optional)
# ------------------------

FROM base AS minerl-env
RUN apt-get update && apt-get install -y \
    openjdk-8-jdk libx11-6 x11-xserver-utils \
    && rm -rf /var/lib/apt/lists/*
RUN pip3 install minerl==0.4.2.1

# ------------------------
# base
# ------------------------

FROM ${ENV}-env AS final-base

# ------------------------
# PyDreamer
# ------------------------

FROM ${ENV}-env AS final-full

WORKDIR /app

COPY requirements.txt .
RUN pip3 install -r requirements.txt
RUN pip3 install git+https://github.com/jurgisp/gym-minigrid.git@2e5a1cf878778dc33a6fd5c5288f81e71d6c6c1c#egg=gym-minigrid
RUN pip3 install git+https://github.com/jurgisp/gym-miniworld.git@e551b6c7ca245ca8f4e31471819728fb46ca256d#egg=gym-miniworld dmlab-maze-generator

ENV MLFLOW_TRACKING_URI ""
ENV MLFLOW_EXPERIMENT_NAME "Default"
ENV OMP_NUM_THREADS 1
ENV PYTHONUNBUFFERED 1
ENV LANG "C.UTF-8"

COPY . .

# ------------------------
# final
# ------------------------

FROM final-${TYPE} AS final
ENTRYPOINT ["sh", "scripts/xvfb_run.sh", "python3", "train.py"]
