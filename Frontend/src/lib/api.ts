import { supabase } from './supabase';

const baseUrl = (import.meta.env.VITE_API_URL as string | undefined) || 'http://localhost:4000/api/v1';
export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const { data } = await supabase.auth.getSession();
  const response = await fetch(`${baseUrl}${path}`, { ...init, headers: { 'Content-Type': 'application/json', ...(data.session?.access_token ? { Authorization: `Bearer ${data.session.access_token}` } : {}), ...init.headers } });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(payload?.error?.message || 'Something went wrong. Please try again.');
  return payload.data as T;
}
