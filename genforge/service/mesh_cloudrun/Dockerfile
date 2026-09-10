# GenForge mesh service — Cloud Run GPU (nvidia-l4). PARKED 2026-09-10 for
# budget (canon §12.38) — kept intact, see PARKED.md; docs/tech/31 §7.
# Build args pick the backend; weights bake into the image at build time so
# cold starts stream the image instead of re-downloading weights every boot.
#   docker build --build-arg MODEL=hunyuan3d -t $IMG genforge/service/mesh_cloudrun
# NOTE: upstream repos move fast — pin the commits below when first deploying
# and record them in the image label.

FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ARG MODEL=hunyuan3d
ENV MODEL=${MODEL} \
    DEBIAN_FRONTEND=noninteractive \
    HF_HOME=/opt/hf \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.10 python3-pip python3.10-venv git libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir torch torchvision \
        --index-url https://download.pytorch.org/whl/cu124 \
    && pip3 install --no-cache-dir fastapi uvicorn pillow trimesh

# --- backend: Hunyuan3D-2 (default) --------------------------------------
# PIN a commit before production use.
RUN if [ "$MODEL" = "hunyuan3d" ]; then \
        git clone --depth 1 https://github.com/Tencent/Hunyuan3D-2 /opt/model \
        && pip3 install --no-cache-dir -r /opt/model/requirements.txt \
        && pip3 install --no-cache-dir -e /opt/model \
        && python3 -c "from huggingface_hub import snapshot_download; \
            snapshot_download('tencent/Hunyuan3D-2')" ; fi

# --- backend: TRELLIS ------------------------------------------------------
RUN if [ "$MODEL" = "trellis" ]; then \
        git clone --depth 1 --recurse-submodules \
            https://github.com/microsoft/TRELLIS /opt/model \
        && cd /opt/model && ./setup.sh --basic --flash-attn --diffoctreerast \
            --spconv --mipgaussian --kaolin --nvdiffrast \
        && python3 -c "from huggingface_hub import snapshot_download; \
            snapshot_download('microsoft/TRELLIS-image-large')" ; fi

ENV PYTHONPATH=/opt/model
COPY server.py /app/server.py
WORKDIR /app

# Cloud Run injects PORT; single worker — the lock in server.py serializes
# the GPU anyway, and concurrency is capped at deploy time.
CMD exec python3 -m uvicorn server:app --host 0.0.0.0 --port ${PORT:-8080}
