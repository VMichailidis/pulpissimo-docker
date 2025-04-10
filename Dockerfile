FROM ubuntu:20.04 as base
#avoid questions
ARG DEBIAN_FRONTEND=noninteractive 
# VARIABLES
ENV INSTALL_DIR="install-files"
ENV VIVADO_FILE="Xilinx_Unified_2022.2_1014_8888.tar.gz"
ENV VIVADO_CONFIG="vivado_config.txt"
ENV MODELSIM_FILE="modelsim.tar.gz"
ENV HOME=/home/pulp
ENV MODELSIM_DIR="/tools"

# create primary user
RUN adduser --disabled-password --gecos '' pulp
# install overall system dependencies
RUN sed -i -e "s%http://[^ ]\+%http://ftp.jaist.ac.jp/pub/Linux/ubuntu/%g" /etc/apt/sources.list
RUN dpkg --add-architecture i386
RUN --mount=type=bind,source=./${INSTALL_DIR}/,target=/${INSTALL_DIR} \
  apt-get update -y && \
  apt-get install -y autoconf automake bc bison build-essential ca-certificates curl dbus dbus-x11 expat:i386 flex fontconfig:i386 fonts-droid-fallback fonts-ubuntu-font-family-console gawk gcc-multilib git g++-multilib gperf gtk2-engines lib32gcc1 lib32stdc++6 lib32z1 libc6-dev:i386 libc6:i386 libcanberra0:i386 git libexpat1:i386 libfreetype6:i386 libgmp-dev libgtk-3-0:i386 libice6:i386 libjpeg62-dev libmpc-dev libmpfr-dev libncurses5:i386 libsm6:i386 libtinfo5 libtool libx11-6:i386 libxau6:i386 libxdmcp6:i386 libxext6:i386 libxft2:i386 libxrender1:i386 libxt6:i386 libxtst6:i386 locales lxappearance minicom ocl-icd-opencl-dev openocd patchutils python python3-pip sudo texinfo texinfo ttf-ubuntu-font-family ubuntu-gnome-default-settings wget xauth xorg zlib1g-dev zlib1g:i386 && \
  apt-get autoclean && \
  apt-get autoremove
USER root
RUN --mount=type=bind,source=./${INSTALL_DIR}/,target=/${INSTALL_DIR} \
  python3 -m pip install --user -r /${INSTALL_DIR}/requirements.txt


# Set the locale
USER root
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8  
ENV LANGUAGE=en_US:en  
ENV LC_ALL=en_US.UTF-8     


# VIVADO
# MODELSIM
# RUN mkdir ${MODELSIM_DIR}
# RUN wget -c ${MODELSIM_URL} -O ${MODELSIM_DIR}/modelsim-${MODELSIM_VERSION}-linux.run

FROM base AS vivado
# download files
# COPY install_files/${VIVADO_FILE} /vivado-installer/
# COPY ${VIVADO_CONFIG} /vivado-installer/

RUN mkdir /vivado-installer
RUN --mount=type=bind,source=./${INSTALL_DIR}/,target=/${INSTALL_DIR} \
  cat /${INSTALL_DIR}/${VIVADO_FILE} | tar zx --strip-components=1 -C /vivado-installer && \
    /vivado-installer/xsetup \
       --agree XilinxEULA,3rdPartyEULA \
       --batch Install \
       --config /${INSTALL_DIR}/${VIVADO_CONFIG} && \
         rm -rvf /vivado-installer

FROM vivado AS modelsim

USER root
# Set the working directory to the ModelSim installation directory
WORKDIR ${MODELSIM_DIR}

# Install ModelSim
RUN --mount=type=bind,source=./${INSTALL_DIR}/,target=/${INSTALL_DIR} \
  tar -xvzf /${INSTALL_DIR}/modelsim.tar.gz -C /tools/ && \
  mkdir -p /usr/tmp/.flexlm/ && \
  cp /${INSTALL_DIR}/LICENSE.TXT /usr/tmp/.flexlm/

WORKDIR ${HOME}

FROM modelsim AS pulpissimo

USER root
RUN mkdir ${HOME}/.pulp-platform
WORKDIR ${HOME}/.pulp-platform
# RISC-V GNU compiler toolchain (not prebuilt)
RUN git clone --recursive --branch renzo-isa https://github.com/pulp-platform/pulp-riscv-gnu-toolchain
WORKDIR ${HOME}/.pulp-platform/pulp-riscv-gnu-toolchain
RUN git checkout 5d39fed
RUN git checkout -b development # development will happen from this branch onward
# build the linux multilib cross compiler
RUN ./configure --prefix=/opt/riscv --with-arch=rv32imc --with-cmodel=medlow --enable-multilib
RUN make

# RISC-V GNU compiler toolchain (prebuilt)
WORKDIR ${HOME}/.pulp-platform
RUN curl -L -o pulp-gcc-2.1.3-centos7.tar.gz 'https://github.com/pulp-platform/riscv-gnu-toolchain/releases/download/v2.1.3/pulp-gcc-2.1.3-centos7.tar.gz' && \
  tar -xvzf pulp-gcc-2.1.3-centos7.tar.gz && \
  rm pulp-gcc-2.1.3-centos7.tar.gz

WORKDIR ${HOME}/.pulp-platform
# Setup pulp-runtime
# add toolchain to path
ENV PULP_RISCV_GCC_TOOLCHAIN=${HOME}/.pulp-platform/pulp-gcc-2.1.3
ENV PATH=${PULP_RISCV_GCC_TOOLCHAIN}/bin:${PATH}

RUN git clone --recursive https://github.com/pulp-platform/pulp-runtime/
WORKDIR ${HOME}/.pulp-platform/pulp-runtime
RUN git checkout a39271c
RUN git checkout -b development # development will happen from this branch onward
ENV PATH=${HOME}/pulp-runtime/bin:${PATH}

WORKDIR ${HOME}/.pulp-platform
# pulpissimo 
ENV VSIM_PATH=pulpissimo/sim
RUN git clone --recursive https://github.com/pulp-platform/pulpissimo
WORKDIR ${HOME}/.pulp-platform/pulpissimo
RUN git checkout 1045d39 
RUN git checkout -b development

WORKDIR ${HOME}/.pulp-platform
RUN git clone --recursive https://github.com/pulp-platform/pulp-runtime-examples
WORKDIR ${HOME}/.pulp-platform/pulp-runtime-examples
RUN git checkout 4391c68 
RUN git checkout -b development

WORKDIR ${HOME}/.pulp-platform
RUN git clone --recursive https://github.com/pulp-platform/pulp-freertos
WORKDIR ${HOME}/.pulp-platform/pulp-freertos
RUN git checkout 1f333de
RUN git checkout -b development

FROM pulpissimo AS sshserver

# Install openssh-server
RUN apt-get install -y openssh-server vim

# Set up SSH - create a directory for sshd, enable ssh, and expose port 22
RUN mkdir /var/run/sshd

# Open port 22 for SSH
EXPOSE 22

# Modify the sshd_config file using 'sed' or 'echo'
# Allow root login via SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Allow password-based authentication
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Generate host keys
USER root
RUN ssh-keygen -A && \
    service ssh start

# Adding source command to the root user's .bashrc file
USER root
RUN echo "export PATH=/tools/MentorGraphics/modeltech/linux_x86_64:/home/pulp/pulp-runtime/bin:/home/pulp/.pulp-platform/pulp-gcc-2.1.3/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/tools/Xilinx/Vivado/2022.2/bin:/tools/Xilinx/Vitis_HLS/2022.2/bin" >> /home/pulp/.bashrc && \
    echo "source /tools/Xilinx/Vitis_HLS/2022.2/settings64.sh" >> /home/pulp/.bashrc && \
    echo "source /tools/Xilinx/Vivado/2022.2/settings64.sh" >> /home/pulp/.bashrc && \
    echo "export LM_LICENSE_FILE=/usr/tmp/.flexlm/LICENSE.TXT" >> /home/pulp/.bashrc && \
    echo "export LD_LIBRARY_PATH=/tools/Xilinx/Vivado/2022.2/lib/lnx64.o:$LD_LIBRARY_PATH" >> /home/pulp/.bashrc && \
    echo "export LD_PRELOAD=/lib/x86_64-linux-gnu/libudev.so.1" >> /home/pulp/.bashrc


# Change the root password
USER root
RUN chown -R pulp:pulp /home/pulp/.local && \
    chown -R pulp:pulp /home/pulp/.pulp-platform

RUN echo 'root:ubuntu20#$' | chpasswd && \
    echo 'pulp:ubuntu20#$' | chpasswd

# RUN source home/pulp/.pulp-platform/pulp-runtime/configs/pulpissimo_cv32.sh &&\
RUN cd /home/pulp/.pulp-platform/pulpissimo && \
    make checkout

USER pulp
WORKDIR ${HOME}
