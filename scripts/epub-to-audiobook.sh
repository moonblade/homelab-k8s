#!/bin/bash
# epub-to-audiobook.sh - Fire-and-forget EPUB to audiobook conversion
# 
# Usage: ./epub-to-audiobook.sh /path/to/book.epub [output-name] [voice]
#
# This script:
# 1. Copies your EPUB to the NFS audiobooks share
# 2. Launches a Kubernetes Job to convert it
# 3. Exits immediately - conversion runs in background
#
# Prerequisites:
# - KUBECONFIG pointing to sirius cluster (or use default ~/.kube/sirius.yaml)
# - Access to NFS share at 192.168.1.10:/mnt/primary/root/audiobooks
#   (either direct mount or via kubectl cp)

set -euo pipefail

# Configuration
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/sirius.yaml}"
NAMESPACE="kokoro"
NFS_SERVER="192.168.1.10"
NFS_PATH="/mnt/primary/root/audiobooks"
DEFAULT_VOICE="am_michael"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <epub-file> [output-name] [voice]"
    echo ""
    echo "Arguments:"
    echo "  epub-file    Path to the EPUB file to convert"
    echo "  output-name  Name for output directory (default: epub filename without extension)"
    echo "  voice        Kokoro voice to use (default: $DEFAULT_VOICE)"
    echo ""
    echo "Available voices: af_nicole, af_bella, af_sarah, am_adam, am_michael, bf_emma, bm_george"
    echo ""
    echo "Examples:"
    echo "  $0 ~/Downloads/mybook.epub"
    echo "  $0 ~/Downloads/mybook.epub my-audiobook af_bella"
    exit 1
}

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Validate arguments
[[ $# -lt 1 ]] && usage
EPUB_FILE="$1"
[[ ! -f "$EPUB_FILE" ]] && error "File not found: $EPUB_FILE"
[[ "${EPUB_FILE##*.}" != "epub" ]] && error "File must be an EPUB: $EPUB_FILE"

# Set defaults
EPUB_BASENAME=$(basename "$EPUB_FILE" .epub)
OUTPUT_NAME="${2:-$EPUB_BASENAME}"
VOICE="${3:-$DEFAULT_VOICE}"
JOB_NAME="epub-convert-$(echo "$OUTPUT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | head -c 50)-$(date +%s)"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
INPUT_DIR="_inbox/${TIMESTAMP}"

log "Converting: $EPUB_FILE"
log "Output name: $OUTPUT_NAME"
log "Voice: $VOICE"
log "Job name: $JOB_NAME"

# Step 1: Copy EPUB to NFS via kubectl cp (through the running pod)
log "Copying EPUB to cluster..."

# First create the inbox directory
kubectl --kubeconfig="$KUBECONFIG" exec -n "$NAMESPACE" deploy/kokoro -c epub-to-audiobook -- \
    mkdir -p "/audiobooks/$INPUT_DIR" 2>/dev/null || true

# Copy the file
kubectl --kubeconfig="$KUBECONFIG" cp "$EPUB_FILE" \
    "$NAMESPACE/$(kubectl --kubeconfig="$KUBECONFIG" get pod -n "$NAMESPACE" -l app=kokoro -o jsonpath='{.items[0].metadata.name}'):/audiobooks/$INPUT_DIR/input.epub" \
    -c epub-to-audiobook

log "EPUB copied to /audiobooks/$INPUT_DIR/input.epub"

# Step 2: Create and apply the Job manifest
log "Creating conversion job..."

cat <<EOF | kubectl --kubeconfig="$KUBECONFIG" apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
  namespace: $NAMESPACE
  labels:
    app: epub-to-audiobook
    type: conversion-job
spec:
  ttlSecondsAfterFinished: 86400  # Cleanup after 24h
  backoffLimit: 1
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: converter
          image: ghcr.io/p0n1/epub_to_audiobook:latest
          command:
            - python3
            - /app_src/main.py
          args:
            - /audiobooks/$INPUT_DIR/input.epub
            - /audiobooks/$OUTPUT_NAME
            - --tts
            - openai
            - --voice_name
            - $VOICE
            - --model_name
            - kokoro
            - --no_prompt
            - --log
            - INFO
          env:
            - name: OPENAI_API_KEY
              value: fake
            - name: OPENAI_BASE_URL
              value: http://kokoro.kokoro.svc.cluster.local:8880/v1
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          volumeMounts:
            - name: audiobooks
              mountPath: /audiobooks
      volumes:
        - name: audiobooks
          nfs:
            server: $NFS_SERVER
            path: $NFS_PATH
            readOnly: false
EOF

log "Job created: $JOB_NAME"
log "Output will be at: /audiobooks/$OUTPUT_NAME"
echo ""

log "Waiting for pod to start..."
for i in {1..60}; do
    POD_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get pods -n "$NAMESPACE" -l "job-name=$JOB_NAME" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "Pending")
    case "$POD_STATUS" in
        Running)
            break
            ;;
        Succeeded|Failed)
            break
            ;;
        *)
            sleep 1
            ;;
    esac
done

echo ""
log "Streaming progress (Ctrl+C to detach - conversion continues in background):"
echo "─────────────────────────────────────────────────────────────"

sleep 2
kubectl --kubeconfig="$KUBECONFIG" logs -n "$NAMESPACE" "job/$JOB_NAME" -f 2>&1 || {
    echo ""
    JOB_STATUS=$(kubectl --kubeconfig="$KUBECONFIG" get job -n "$NAMESPACE" "$JOB_NAME" -o jsonpath='{.status.conditions[0].type}' 2>/dev/null)
    if [[ "$JOB_STATUS" == "Failed" ]]; then
        error "Job failed. Check logs: kubectl --kubeconfig=$KUBECONFIG logs -n $NAMESPACE job/$JOB_NAME"
    else
        warn "Logs not yet available. Check manually:"
        echo "  kubectl --kubeconfig=$KUBECONFIG logs -n $NAMESPACE job/$JOB_NAME -f"
    fi
}
