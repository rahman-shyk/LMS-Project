import type { RequestHandler } from 'express';
import type { ZodType } from 'zod';
export const validateBody = (schema: ZodType): RequestHandler => (req, res, next) => {
  const parsed = schema.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: { code: 'VALIDATION_ERROR', message: parsed.error.issues[0]?.message || 'Please check the submitted fields.' } });
  req.body = parsed.data; next();
};
