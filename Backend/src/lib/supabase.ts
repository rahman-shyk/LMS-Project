import { createClient } from '@supabase/supabase-js';
import type { Request } from 'express';

const url = process.env.SUPABASE_URL || 'https://placeholder.supabase.co';
const anonKey = process.env.SUPABASE_ANON_KEY || 'placeholder-anon-key';
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-service-role-key';
export const supabaseAdmin = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
export const createPublicClient = () => createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false } });
const requestClients = new WeakMap<object, any>();
export function userDb(req: Request): any {
  const key = req as object;
  let client = requestClients.get(key);
  if (!client) {
    client = createClient(url, anonKey, { auth: { autoRefreshToken: false, persistSession: false }, global: { headers: { Authorization: req.headers.authorization || '' } } });
    requestClients.set(key, client);
  }
  return client;
}
