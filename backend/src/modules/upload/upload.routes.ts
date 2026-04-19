import { Router, Request, Response } from 'express';
import multer from 'multer';
import asyncHandler from '../../shared/http/asyncHandler.js';
import { uploadFile } from './upload.service.js';

const router = Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024 }, // 8 MB
  fileFilter: (_req, file, cb) => {
    if (!file.mimetype.startsWith('image/')) {
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
