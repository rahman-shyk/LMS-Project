import type { NextFunction, Response } from 'express';
import { supabaseAdmin } from '../lib/supabase.js';
import type { AuthRequest, Role } from '../types.js';

export async function requireAuth(req: AuthRequest, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.match(/^Bearer\s+(.+)$/i)?.[1];
  if (!token) return res.status(401).json({ error: { code: 'UNAUTHENTICATED', message: 'Please sign in to continue.' } });
  const { data: auth, error: authError } = await supabaseAdmin.auth.getUser(token);
  if (authError || !auth.user) return res.status(401).json({ error: { code: 'INVALID_SESSION', message: 'Your session is invalid or expired.' } });
  const { data: profile, error } = await supabaseAdmin.from('profiles').select('*').eq('id', auth.user.id).maybeSingle();
  if (error || !profile || !profile.is_active) return res.status(403).json({ error: { code: 'ACCOUNT_INACTIVE', message: 'This account is inactive.' } });
  req.profile = profile;
  next();
}
export function requireRole(...roles: Role[]) {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.profile || !roles.includes(req.profile.role)) return res.status(403).json({ error: { code: 'FORBIDDEN', message: 'You do not have permission to do that.' } });
    next();
  };
}
