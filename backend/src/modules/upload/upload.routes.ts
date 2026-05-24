import { Router, Request, Response } from 'express';
import multer from 'multer';
import { fromBuffer as fileTypeFromBuffer } from 'file-type';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { uploadImageWithVariants } from './upload.service.js';

const router = Router();

// Accept the same three input formats we did before. Sharp will decode
// any of them and re-encode to WebP for storage, so the on-disk format
// is uniform regardless of what the client sent.
const ALLOWED_MIMES = new Set<string>(['image/jpeg', 'image/png', 'image/webp']);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 }, // 8 MB
  // No fileFilter here — extension/mimetype can be spoofed by the client.
  // We validate the actual bytes below via file-type's magic-byte sniffing.
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
      res.status(400).json({ error: 'Only JPEG, PNG, or WebP images are allowed' });
      return;
    }
    // Re-encode + resize on upload so the storage layer is uniform
    // WebP at 3 widths. Response includes both the default url (md)
    // and the variant map so clients can request the size they need.
    const result = await uploadImageWithVariants(req.file.buffer, req.file.originalname);
    res.status(201).json(result);
  }),
);

export default router;
