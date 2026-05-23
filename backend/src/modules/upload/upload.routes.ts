import { Router, Request, Response } from 'express';
import multer from 'multer';
import { fromBuffer as fileTypeFromBuffer } from 'file-type';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { uploadFile } from './upload.service.js';

const router = Router();

// We resize/serve as the original mime; sticking to widely-supported formats
// avoids surprises (HEIC/AVIF/TIFF render unevenly across browsers, and GIF/BMP
// aren't worth the validation surface area).
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
    // Use the sniffed mime — never trust the client-supplied one.
    const { url } = await uploadFile(req.file.buffer, req.file.originalname, sniffed.mime);
    res.status(201).json({ url });
  }),
);

export default router;
