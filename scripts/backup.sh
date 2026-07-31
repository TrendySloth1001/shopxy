#!/usr/bin/env bash
# Snapshot the stack's data (Postgres + MinIO) into one portable tarball for
# moving to a new server. Run from the repo root while the OLD server's
# stack is still up. See readmes/deploy-migration.md for the full runbook.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "error: .env not found — run from the repo root with the stack configured" >&2
  exit 1
fi
set -a; source .env; set +a

STAMP=$(date +%Y%m%d-%H%M%S)
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

echo "==> Dumping Postgres (${POSTGRES_DB})..."
docker compose exec -T postgres pg_dump -U "${POSTGRES_USER}" -Fc "${POSTGRES_DB}" > "$WORKDIR/db.dump"

echo "==> Archiving MinIO data..."
MINIO_CID=$(docker compose ps -q minio)
docker run --rm --volumes-from "$MINIO_CID" -v "$WORKDIR:/backup" alpine \
  tar czf /backup/minio-data.tar.gz -C /data .

OUT="shopxy-backup-${STAMP}.tar.gz"
tar czf "$OUT" -C "$WORKDIR" db.dump minio-data.tar.gz
echo "==> Wrote $OUT"
echo "    Copy it to the new server, e.g.: scp $OUT user@newhost:~/shopxy/"
