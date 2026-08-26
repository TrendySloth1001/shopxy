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

  const url = `/images/${key}`;
  return { key, url };
}

export async function deleteFile(key: string): Promise<void> {
  await s3.send(new DeleteObjectCommand({ Bucket: MINIO_BUCKET, Key: key }));
}

const VARIANTS = {
  sm: 160,
  md: 600,
  lg: 1600,
} as const;
type Variant = keyof typeof VARIANTS;

export interface UploadedImage {
  url: string;
  id: string;
  variants: Record<Variant, string>;
}

export async function uploadImageWithVariants(
  buffer: Buffer,
  _originalName: string,
): Promise<UploadedImage> {
  const id = crypto.randomUUID();

  const encoded = await Promise.all(
    (Object.entries(VARIANTS) as [Variant, number][]).map(async ([variant, width]) => {
      const out = await sharp(buffer, { failOn: 'truncated' })
        .rotate()
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

export function urlFor(storedUrl: string, variant: Variant): string {
  const match = storedUrl.match(/^(.*)-(sm|md|lg)\.webp$/);
  if (!match) return storedUrl;
  return `${match[1]}-${variant}.webp`;
}

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
