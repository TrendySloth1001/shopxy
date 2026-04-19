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
import path from 'path';

const MINIO_ENDPOINT = process.env.MINIO_ENDPOINT ?? 'localhost';
const MINIO_PORT = Number(process.env.MINIO_PORT ?? 9000);
const MINIO_ACCESS_KEY = process.env.MINIO_ACCESS_KEY ?? 'shopxy';
const MINIO_SECRET_KEY = process.env.MINIO_SECRET_KEY ?? 'shopxy123';
export const MINIO_BUCKET = process.env.MINIO_BUCKET ?? 'shopxy-images';
export const MINIO_PUBLIC_URL = (process.env.MINIO_PUBLIC_URL ?? 'http://localhost:3005').replace(/\/$/, '');

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

export async function uploadFile(
  buffer: Buffer,
  originalName: string,
  mimeType: string,
): Promise<{ key: string; url: string }> {
  const ext = path.extname(originalName).toLowerCase() || '.bin';
  const key = `${crypto.randomUUID()}${ext}`;

  await s3.send(
    new PutObjectCommand({
      Bucket: MINIO_BUCKET,
      Key: key,
      Body: buffer,
      ContentType: mimeType,
    }),
  );

  const url = `${MINIO_PUBLIC_URL}/images/${key}`;
  return { key, url };
}

export async function deleteFile(key: string): Promise<void> {
  await s3.send(new DeleteObjectCommand({ Bucket: MINIO_BUCKET, Key: key }));
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
