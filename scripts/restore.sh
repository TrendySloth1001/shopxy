#!/usr/bin/env bash
# Restore a tarball produced by backup.sh onto a new server. Run AFTER
# `docker compose up -d postgres minio` on the new box (so the containers
# exist) and BEFORE starting backend/merchant-web/customer-web. See
# readmes/deploy-migration.md for the full runbook.
set -euo pipefail
cd "$(dirname "$0")/.."

ARCHIVE="${1:-}"
if [ -z "$ARCHIVE" ]; then
  echo "usage: $0 <shopxy-backup-TIMESTAMP.tar.gz>" >&2
  exit 1
fi
if [ ! -f .env ]; then
  echo "error: .env not found — copy .env.example to .env and fill it in first" >&2
  exit 1
fi
set -a; source .env; set +a

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT
tar xzf "$ARCHIVE" -C "$WORKDIR"

echo "==> Starting Postgres + MinIO..."
docker compose up -d postgres minio
until docker compose exec -T postgres pg_isready -U "${POSTGRES_USER}" >/dev/null 2>&1; do sleep 1; done

echo "==> Restoring Postgres (${POSTGRES_DB})..."
docker compose exec -T postgres pg_restore -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" --clean --if-exists < "$WORKDIR/db.dump"

echo "==> Restoring MinIO data..."
MINIO_CID=$(docker compose ps -q minio)
docker run --rm --volumes-from "$MINIO_CID" -v "$WORKDIR:/backup" alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/minio-data.tar.gz -C /data"

echo "==> Restore complete. Bring up the rest of the stack:"
echo "    docker compose up -d"
