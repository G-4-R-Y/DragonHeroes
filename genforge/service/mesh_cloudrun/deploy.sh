#!/usr/bin/env bash
# GenForge mesh service — Cloud Run GPU deploy. PARKED 2026-09-10 for budget
# (canon §12.38): GUARDED below so nothing can reach GCP by accident. The
# design is the PREFERRED max-quality tier — re-enable when budget allows.
# docs/tech/31 §7 is the law; this script is the runbook's executable half.
# Idempotent: re-run to update.
#
# CREDENTIALS MAP — the only three places anything sensitive ever lives:
#   1. ~/.config/gcloud/            gcloud auth login (browser flow, ONCE).
#                                   Used for: build, deploy, AND invoking
#                                   (mesh_gen mints identity tokens from it).
#   2. .env.local (repo root,       DH_MESH_CLOUDRUN_URL=<printed at the end>
#      gitignored)                  Not a secret, but machine-specific.
#   3. Secret Manager (optional)    Only if a future GATED model needs an
#                                   HF token: gcloud secrets create hf-token,
#                                   then add --set-secrets below. NEVER a key
#                                   file in the repo.
# A service-account JSON key is NOT needed for solo use; for a headless CI
# invoker later: create an SA, grant roles/run.invoker, and point
# GOOGLE_APPLICATION_CREDENTIALS at its key outside the repo.
set -euo pipefail

if [ "${DH_CLOUD_TIER_ENABLED:-0}" != "1" ]; then
    echo "PARKED (canon §12.38): the cloud GPU tier is disabled for budget."
    echo "Set DH_CLOUD_TIER_ENABLED=1 to run this deploy. See PARKED.md."
    exit 1
fi

# ---- knobs (edit these, or override via env) --------------------------------
PROJECT="${DH_GCP_PROJECT:?set DH_GCP_PROJECT — use a dedicated project (dragon-heroes-dev), NOT a shared one}"
REGION="${DH_GCP_REGION:-us-central1}"      # needs Cloud Run GPU (nvidia-l4)
MODEL="${DH_MESH_MODEL:-hunyuan3d}"          # hunyuan3d | trellis
SERVICE="dh-mesh-${MODEL}"
REPO="dh-genforge"
IMG="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${SERVICE}:latest"

gcloud config set project "${PROJECT}"

# one-time enables + registry (safe to re-run)
gcloud services enable run.googleapis.com artifactregistry.googleapis.com \
    cloudbuild.googleapis.com
gcloud artifacts repositories describe "${REPO}" --location "${REGION}" \
    >/dev/null 2>&1 || gcloud artifacts repositories create "${REPO}" \
    --repository-format docker --location "${REGION}"

# build in the cloud (the image bakes ~10-20 GB of weights — don't upload
# from a laptop connection; Cloud Build pulls everything server-side)
gcloud builds submit --tag "${IMG}" --timeout 3600 \
    --machine-type e2-highcpu-32 "$(dirname "$0")"

# deploy: private service, one L4, scale-to-zero, serialized requests
gcloud run deploy "${SERVICE}" \
    --image "${IMG}" \
    --region "${REGION}" \
    --gpu 1 --gpu-type nvidia-l4 \
    --memory 32Gi --cpu 8 \
    --concurrency 1 --max-instances 1 --min-instances 0 \
    --timeout 900 \
    --no-allow-unauthenticated \
    --set-env-vars MODEL="${MODEL}" \
    --no-gpu-zonal-redundancy

# let YOUR account invoke it (repeat for an SA later if CI needs it)
CALLER="$(gcloud config get-value account)"
gcloud run services add-iam-policy-binding "${SERVICE}" --region "${REGION}" \
    --member "user:${CALLER}" --role roles/run.invoker

URL="$(gcloud run services describe "${SERVICE}" --region "${REGION}" \
    --format 'value(status.url)')"
echo
echo "==> deployed. Put this in .env.local (or ~/.bashrc):"
echo "export DH_MESH_CLOUDRUN_URL=${URL}"
echo "==> smoke: curl -H \"Authorization: Bearer \$(gcloud auth print-identity-token)\" ${URL}/health"
