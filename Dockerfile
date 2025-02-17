FROM ubuntu:xenial AS base
#avoid questions
ARG DEBIAN_FRONTEND=noninteractive 
# VARIABLES
ENV VIVADO_FILE="Xilinx_Unified_2022.2_1014_8888.tar.gz"
ENV VIVADO_CONFIG="vivado_config.txt"
ENV MODELSIM_VERSION=20.1.1.720
ENV MODELSIM_URL=https://downloads.intel.com/akdlm/software/acdsinst/20.1std.1/720/ib_installers/ModelSimSetup-20.1.1.720-linux.run
ENV HOME=/home/pulp
ENV MODELSIM_DIR="${HOME}/intelFPGA"

# create primary user
RUN adduser --disabled-password --gecos '' pulp
WORKDIR $HOME

USER pulp
RUN mkdir -p ${HOME}/default_packages
COPY pkglist ${HOME}/default_packages/pkglist
COPY requirements.txt ${HOME}/default_packages/requirements.txt

USER root
# install overall system dependencies
RUN sed -i -e "s%http://[^ ]\+%http://ftp.jaist.ac.jp/pub/Linux/ubuntu/%g" /etc/apt/sources.list
RUN dpkg --add-architecture i386
RUN apt-get -y update && \
  apt-get install -y $(cat default_packages/pkglist) && \
  apt-get autoclean && \
  apt-get autoremove
USER pulp
RUN python3 -m pip install --user -r ${HOME}/default_packages/requirements.txt

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
COPY ${VIVADO_CONFIG} /vivado-installer/
COPY install_files/${VIVADO_FILE} /vivado-installer/

RUN \
  cat /vivado-installer/${VIVADO_FILE} | tar zx --strip-components=1 -C /vivado-installer && \
    /vivado-installer/xsetup \
       --agree XilinxEULA,3rdPartyEULA \
       --batch Install \
       --config /vivado-installer/${VIVADO_CONFIG} && \
         rm -rvf /vivado-installer

FROM vivado AS modelsim

USER pulp
# Set the working directory to the ModelSim installation directory
WORKDIR ${MODELSIM_DIR}

# Download the ModelSim installer
RUN wget -c ${MODELSIM_URL} -O modelsim-${MODELSIM_VERSION}-linux.run

# Make the installer executable, run it, and then clean up the installer
RUN chmod a+x modelsim-${MODELSIM_VERSION}-linux.run && \
    ./modelsim-${MODELSIM_VERSION}-linux.run --mode unattended \
    --accept_eula 1 --installdir ${MODELSIM_DIR} && \
    rm -rf modelsim-${MODELSIM_VERSION}-linux.run ${MODELSIM_DIR}/uninstall

WORKDIR ${HOME}

FROM modelsim AS final

USER root
RUN mkdir ${HOME}/pulp-platform
WORKDIR ${HOME}/pulp-platform
# RISC-V GNU compiler toolchain 
RUN git clone --recursive --branch renzo-isa https://github.com/pulp-platform/pulp-riscv-gnu-toolchain
WORKDIR ${HOME}/pulp-platform/pulp-riscv-gnu-toolchain
RUN git checkout 5d39fed
RUN git checkout -b development # development will happen from this branch onward
# build the linux multilib cross compiler
RUN ./configure --prefix=/opt/riscv --with-arch=rv32imc --with-cmodel=medlow --enable-multilib
RUN make

WORKDIR ${HOME}/pulp-platform
# Setup pulp-runtime
# add toolchain to path
ENV PULP_RISCV_GCC_TOOLCHAIN=/opt/riscv
ENV PATH=${PULP_RISCV_GCC_TOOLCHAIN}/bin:${PATH}

RUN git clone --recursive https://github.com/pulp-platform/pulp-runtime/
WORKDIR ${HOME}/pulp-platform/pulp-runtime
RUN git checkout a39271c
RUN git checkout -b development # development will happen from this branch onward
ENV PATH=${HOME}/pulp-runtime/bin:${PATH}

WORKDIR ${HOME}/pulp-platform
# pulpissimo 
ENV VSIM_PATH=pulpissimo/sim
RUN git clone --recursive https://github.com/pulp-platform/pulpissimo
WORKDIR ${HOME}/pulp-platform/pulpissimo
RUN git checkout 1045d39 
RUN git checkout -b development


WORKDIR ${HOME}/pulp-platform
RUN git clone --recursive https://github.com/pulp-platform/pulp-runtime-examples
WORKDIR ${HOME}/pulp-platform/pulp-runtime-examples
RUN git checkout 4391c68 
RUN git checkout -b development


USER pulp
WORKDIR ${HOME}
