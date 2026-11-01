import type { Request } from 'express';
export type Role = 'admin' | 'teacher' | 'student';
export interface Profile { id: string; full_name: string; email: string; role: Role; is_active: boolean; must_change_password: boolean; roll_number: string | null }
export type AuthRequest = Request & { profile?: Profile };
