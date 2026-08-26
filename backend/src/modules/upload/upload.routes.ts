import { Router, Request, Response } from 'express';
import multer from 'multer';
import { fromBuffer as fileTypeFromBuffer } from 'file-type';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { uploadImageWithVariants } from './upload.service.js';

const router = Router();
const ALLOWED_MIMES = new Set<string>(['image/jpeg', 'image/png', 'image/webp']);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 },
});

router.post(
  '/',
  upload.single('file'),
  asyncHandler(async (req: Request, res: Response) => {
    if (!req.file) {
      res.status(400).json({ error: 'No file uploaded' });
      return;
    }
    const sniffed = await fileTypeFromBuffer(req.file.buffer);
    if (!sniffed || !ALLOWED_MIMES.has(sniffed.mime)) {
      res
        .status(400)
        .json({ error: 'Only JPEG, PNG, or WebP images are allowed' });
      return;
    }
    const result = await uploadImageWithVariants(
      req.file.buffer,
      req.file.originalname,
    );
    res.status(201).json(result);
  }),
);

export default router;
