ARG CUDA_VERSION=12.5.0
ARG CUDA_ARCHITECTURES=86;89;90
ARG OS_VERSION=22.04

# Define base image.
FROM mambaorg/micromamba:1.5.10 AS micromamba

# This is the image we are going add micromaba to:
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${OS_VERSION}

USER root

# if your image defaults to a non-root user, then you may want to make the
# next 3 ARG commands match the values in your image. You can get the values
# by running: docker run --rm -it my/image id -a
ARG MAMBA_USER=mambauser
ARG MAMBA_USER_ID=57439
ARG MAMBA_USER_GID=57439
ENV MAMBA_USER=$MAMBA_USER
ENV MAMBA_ROOT_PREFIX="/opt/conda"
ENV MAMBA_EXE="/bin/micromamba"

COPY --from=micromamba "$MAMBA_EXE" "$MAMBA_EXE"
COPY --from=micromamba /usr/local/bin/_activate_current_env.sh /usr/local/bin/_activate_current_env.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_shell.sh /usr/local/bin/_dockerfile_shell.sh
COPY --from=micromamba /usr/local/bin/_entrypoint.sh /usr/local/bin/_entrypoint.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_initialize_user_accounts.sh /usr/local/bin/_dockerfile_initialize_user_accounts.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_setup_root_prefix.sh /usr/local/bin/_dockerfile_setup_root_prefix.sh

RUN /usr/local/bin/_dockerfile_initialize_user_accounts.sh && \
    /usr/local/bin/_dockerfile_setup_root_prefix.sh

USER $MAMBA_USER

SHELL ["/usr/local/bin/_dockerfile_shell.sh"]

ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]
# Optional: if you want to customize the ENTRYPOINT and have a conda
# environment activated, then do this:
# ENTRYPOINT ["/usr/local/bin/_entrypoint.sh", "my_entrypoint_program"]

# You can modify the CMD statement as needed....
CMD ["/bin/bash"]



# Cuda Environment Variables
ENV CUDA_HOME="/usr/local/cuda"
ENV TCNN_CUDA_ARCHITECTURES=${CUDA_ARCHITECTURES}
RUN export TORCH_CUDA_ARCH_LIST="$(echo "$CUDA_ARCHITECTURES" | tr ';' '\n' | awk '$0 > 70 {print substr($0,1,1)"."substr($0,2)}' | tr '\n' ' ' | sed 's/ $//')"


ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
USER root

RUN apt update --fix-missing && apt install -y wget gnupg2 git cmake curl unzip


RUN apt install -y python3 python3-pip python3-venv \
libglew-dev libgl1-mesa-dev libglib2.0-0 libopencv-dev protobuf-compiler libgoogle-glog-dev libboost-all-dev libhdf5-dev libatlas-base-dev

WORKDIR /workspace

#COPY ./requirements.txt /workspace/requirements.txt
COPY ./environments.yaml /workspace/environments.yaml




RUN micromamba install -y -n base -f ./environments.yaml && \
    micromamba clean --all --yes

ARG MAMBA_DOCKERFILE_ACTIVATE=1

RUN curl https://huggingface.co/hbyang/Hi3D/resolve/main/ckpts.zip -L -o ckpts.zip && \
unzip ckpts.zip && \
cd ckpts && \
curl https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/resolve/main/svd_xt_image_decoder.safetensors -L -o svd_xt_image_decoder.safetensors && \
curl https://huggingface.co/hbyang/Hi3D/resolve/main/first_stage.pt -L -o first_stage.pt && \
curl https://huggingface.co/hbyang/Hi3D/resolve/main/second_stage.pt -L -o second_stage.pt

