#FROM vllm/vllm-openai:latest
FROM vllm/vllm-openai:v0.8.5

# System utilities
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    curl git screen build-essential \
    && rm -rf /var/lib/apt/lists/*

# Optional: upgrade pip
RUN pip install --upgrade pip setuptools wheel
RUN pip install --no-cache-dir --upgrade \
    huggingface_hub \
    hf_transfer \
    accelerate

ENV HF_HUB_ENABLE_HF_TRANSFER=1

# Create user
ARG USER=mobs
ARG USER_ID=1005
ARG USER_GROUP=mobs
ARG USER_GROUP_ID=1005

RUN groupadd --gid ${USER_GROUP_ID} ${USER_GROUP} && \
    useradd --create-home --shell /bin/bash \
    --uid ${USER_ID} \
    --gid ${USER_GROUP_ID} ${USER}

# Install additional Python requirements
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# Copy app
COPY . /app/
WORKDIR /app
RUN chown -R ${USER}:${USER_GROUP} /app
RUN chmod +x /app/start_pair_strata.sh
RUN chmod +x /app/start_pair_strata_70.sh
RUN chmod +x /app/start_pair_strata_70_llama.sh
RUN chmod +x /app/start_batch_strata.sh
RUN chmod +x /app/start_batch_strata_70.sh
RUN chmod +x /app/start_batch_strata_70_2.sh
RUN chmod +x /app/start_batch_strata_70_3.sh


USER ${USER}
CMD ["/bin/bash"]

