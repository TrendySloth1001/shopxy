import {
  S3Client,
  PutObjectCommand,
  DeleteObjectCommand,
  GetObjectCommand,
  CreateBucketCommand,
  HeadBucketCommand,
  PutBucketPolicyCommand,
} from '@aws-sdk/client-s3';
import { Readable } from 'stream';
import crypto from 'crypto';
import sharp from 'sharp';

// MinIO/S3 credentials must come from the environment. We refuse to bake
// well-known defaults (`shopxy` / `shopxy123`) into the source — those
// shipped to every deployment and gave any reader of this repo full
// read/write on prod buckets.
function readMinioCreds(): { accessKey: string; secretKey: string } {
  const accessKey = process.env.MINIO_ACCESS_KEY;
  const secretKey = process.env.MINIO_SECRET_KEY;
  if (!accessKey || !secretKey) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'MINIO_ACCESS_KEY and MINIO_SECRET_KEY are required in production. ' +
          'Refusing to fall back to default credentials.',
      );
    }
    // Dev/test convenience only — the production startup above throws,
    // so the same module loaded against a prod NODE_ENV refuses these
    // values. Strings match the docker-compose dev defaults so a fresh
    // checkout + `docker-compose up` works without extra env wiring.
    // eslint-disable-next-line no-console
    console.warn(
      '[upload] MINIO_ACCESS_KEY/SECRET unset; using dev defaults. ' +
        'Production startup will refuse this.',
    );
    return { accessKey: 'shopxy', secretKey: 'shopxy123' };
  }
  return { accessKey, secretKey };
}

const MINIO_ENDPOINT = process.env.MINIO_ENDPOINT ?? 'localhost';
const MINIO_PORT = Number(process.env.MINIO_PORT ?? 9000);
const { accessKey: MINIO_ACCESS_KEY, secretKey: MINIO_SECRET_KEY } = readMinioCreds();
export const MINIO_BUCKET = process.env.MINIO_BUCKET ?? 'shopxy-images';

export const s3 = new S3Client({
  region: 'us-east-1',
  endpoint: `http://${MINIO_ENDPOINT}:${MINIO_PORT}`,
  credentials: { accessKeyId: MINIO_ACCESS_KEY, secretAccessKey: MINIO_SECRET_KEY },
  forcePathStyle: true,
});

export async function ensureBucket(): Promise<void> {
  try {
    await s3.send(new HeadBucketCommand({ Bucket: MINIO_BUCKET }));
  } catch {
    await s3.send(new CreateBucketCommand({ Bucket: MINIO_BUCKET }));
    await s3.send(
      new PutBucketPolicyCommand({
        Bucket: MINIO_BUCKET,
        Policy: JSON.stringify({
          Version: '2012-10-17',
          Statement: [
            {
              Effect: 'Allow',
              Principal: { AWS: ['*'] },
              Action: ['s3:GetObject'],
              Resource: [`arn:aws:s3:::${MINIO_BUCKET}/*`],
            },
          ],
        }),
      }),
    );
  }
}

// Allowed (mimeType → extension) map for legacy `uploadFile`. We never
// trust the client filename's extension — that lets an attacker store
// `evil.svg` (with a JS payload) under a uuid `.svg` key served from
// our origin. Force-derive the extension from the (already-validated
// upstream) mime type, and refuse anything we don't recognise.
//
// CAT-L2 — restricted to the SAME three image types the mounted
// `uploadImageWithVariants` path accepts (JPEG/PNG/WebP). The previous map
// also permitted `image/gif` and `application/pdf`; the mounted route sniffs
// magic bytes and rejects those, but this helper trusts the caller-supplied
// `mimeType` and did not, so a future caller could have stored a `.pdf`/`.gif`
// under our origin. NOTE: this helper still trusts `mimeType` — any caller
// MUST byte-sniff before calling it (the mounted route does); see the route.
const ALLOWED_UPLOAD_EXTENSIONS: Record<string, string> = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/webp': '.webp',
};

export async function uploadFile(
  buffer: Buffer,
  _originalName: string,
  mimeType: string,
): Promise<{ key: string; url: string }> {
  const ext = ALLOWED_UPLOAD_EXTENSIONS[mimeType];
  if (!ext) {
    throw new Error(`Unsupported upload content-type: ${mimeType}`);
  }
  const key = `${crypto.randomUUID()}${ext}`;

  await s3.send(
    new PutObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: key,
      Body: buffer,
      ContentType: mimeType,
    }),
  );

  // Return a **relative path** rather than an absolute URL — the
  // backend has no reliable way to know what host the client will use
  // to reach it (localhost in dev, a devtunnel URL on a phone,
  // a production domain when shipped). The frontend joins this path
  // with its own `apiBaseUrl` at render time, so the same row works
  // for every deployment.
  const url = `/images/${key}`;
  return { key, url };
}

export async function deleteFile(key: string): Promise<void> {
  await s3.send(new DeleteObjectCommand({ Bucket: MINIO_BUCKET, Key: key }));
}

/// Size variants we generate from every uploaded image. `sm` is for
/// thumbnails and category pucks, `md` for grid/list cards, `lg` for anything
/// that fills the screen width — hero banners, product detail.
///
/// `lg` used to be 800px, which is NARROWER than the physical width of every
/// phone we ship to (1080–1440px). A full-bleed hero banner was therefore
/// always upscaled, and since nothing ever called `urlFor`, every surface was
/// actually rendering `md` at 400px — a hero banner upscaled better than 3×.
/// That is the "uploaded banners look bad" report. 1600 covers a 3x-DPR phone
/// at full bleed; `md` at 600 covers a 2-up grid card on the same device.
const VARIANTS = {
  sm: 160,
  md: 600,
  lg: 1600,
} as const;
type Variant = keyof typeof VARIANTS;

export interface UploadedImage {
  /// Default URL — caller should store this. Resolves to the `md`
  /// variant; `urlFor(stored, 'sm' | 'lg')` derives the other sizes.
  url: string;
  /// Stable id shared by all 3 size variants. Useful for cleanup.
  id: string;
  variants: Record<Variant, string>;
}

/// Re-encode + resize the input buffer into three WebP variants and
/// push all of them to object storage. q=75 is roughly the JPEG q=82
/// break-even and is fine for a thumbnail, but a full-bleed hero shows its
/// artefacts, so `lg` gets q=82. EXIF
/// is stripped by sharp by default — important for privacy on
/// user-uploaded photos. Animated inputs render only their first frame
/// (the marketplace doesn't surface video/GIF anywhere yet).
export async function uploadImageWithVariants(
  buffer: Buffer,
  _originalName: string,
): Promise<UploadedImage> {
  const id = crypto.randomUUID();

  const encoded = await Promise.all(
    (Object.entries(VARIANTS) as [Variant, number][]).map(async ([variant, width]) => {
      const out = await sharp(buffer, { failOn: 'truncated' })
        .rotate() // honour EXIF orientation before we strip metadata
        .resize({ width, withoutEnlargement: true })
        .webp({ quality: variant === 'lg' ? 82 : 75, effort: 4 })
        .toBuffer();
      const key = `${id}-${variant}.webp`;
      await s3.send(
        new PutObjectCommand({
          Bucket: MINIO_BUCKET,
          Key: key,
          Body: out,
          ContentType: 'image/webp',
        }),
      );
      return [variant, `/images/${key}`] as const;
    }),
  );

  const variants = Object.fromEntries(encoded) as Record<Variant, string>;
  return { id, url: variants.md, variants };
}

/// Derives a variant URL from any stored variant URL by string swap.
/// Pure function: the variant suffix is part of the storage convention,
/// so we can compute the others without re-querying. Returns input
/// unchanged if it isn't a generated-variant URL (e.g. legacy uploads).
export function urlFor(storedUrl: string, variant: Variant): string {
  const match = storedUrl.match(/^(.*)-(sm|md|lg)\.webp$/);
  if (!match) return storedUrl;
  return `${match[1]}-${variant}.webp`;
}

/// Cleanup helper for delete flows. Removes all 3 variants for a given
/// id. Safe to call against a partial id (e.g. one of the three failed
/// to upload) — missing objects are tolerated by deleteFile.
export async function deleteImageVariants(id: string): Promise<void> {
  await Promise.all(
    (Object.keys(VARIANTS) as Variant[]).map((v) =>
      deleteFile(`${id}-${v}.webp`).catch(() => undefined),
    ),
  );
}

export async function getFileStream(
  key: string,
): Promise<{ stream: Readable; contentType: string } | null> {
  try {
    const response = await s3.send(new GetObjectCommand({ Bucket: MINIO_BUCKET, Key: key }));
    return {
      stream: response.Body as Readable,
      contentType: response.ContentType ?? 'application/octet-stream',
    };
  } catch {
    return null;
  }
}
