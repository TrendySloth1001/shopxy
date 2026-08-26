import { requireSecret } from './env.js';

export const JWT_ACCESS_SECRET = requireSecret('JWT_ACCESS_SECRET');
export const JWT_REFRESH_SECRET = requireSecret('JWT_REFRESH_SECRET');
