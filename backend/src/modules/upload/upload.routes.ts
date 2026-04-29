import { Router, Request, Response } from 'express';
import multer from 'multer';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { uploadFile } from './upload.service.js';

const router = Router();

const IMAGE_EXTENSIONS = new Set([
  '.jpg',
  '.jpeg',
  '.png',
  '.gif',
  '.webp',
  '.bmp',
  '.avif',
  '.heic',
  '.heif',
  '.tif',
  '.tiff',
]);

function isImageFile(file: Express.Multer.File): boolean {
  if (file.mimetype.startsWith('image/')) {
    return true;
  }

  const dotIndex = file.originalname.lastIndexOf('.');
  if (dotIndex === -1) {
    return false;
  }

  return IMAGE_EXTENSIONS.has(file.originalname.slice(dotIndex).toLowerCase());
}

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 }, // 8 MB
  fileFilter: (_req, file, cb) => {
    if (!isImageFile(file)) {
      cb(new Error('Only image files are allowed'));
      return;
    }
    cb(null, true);
  },
});

router.post(
  '/',
  upload.single('file'),
  asyncHandler(async (req: Request, res: Response) => {
    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }
    const { url } = await uploadFile(req.file.buffer, req.file.originalname, req.file.mimetype);
    res.status(201).json({ url });
  }),
);

export default router;
