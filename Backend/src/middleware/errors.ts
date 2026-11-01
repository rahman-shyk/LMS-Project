import type { ErrorRequestHandler, RequestHandler } from 'express';
export const notFound: RequestHandler = (_req, res) => res.status(404).json({ error: { code: 'NOT_FOUND', message: 'That resource could not be found.' } });
export const errorHandler: ErrorRequestHandler = (error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Something went wrong. Please try again.' } });
};
