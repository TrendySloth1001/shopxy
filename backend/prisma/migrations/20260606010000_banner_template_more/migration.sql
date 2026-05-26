-- Extend BannerTemplate with four more visual layouts. Each ADD VALUE
-- is guarded with IF NOT EXISTS so partial reruns (the dev shadow-DB
-- replay path) don't error on already-added labels.

ALTER TYPE "BannerTemplate" ADD VALUE IF NOT EXISTS 'SPLIT';
ALTER TYPE "BannerTemplate" ADD VALUE IF NOT EXISTS 'OVERLAY';
ALTER TYPE "BannerTemplate" ADD VALUE IF NOT EXISTS 'DEAL';
ALTER TYPE "BannerTemplate" ADD VALUE IF NOT EXISTS 'POSTER';
