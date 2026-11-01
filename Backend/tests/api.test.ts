import { describe, expect, it } from 'vitest';
import express from 'express';
import request from 'supertest';
import { app } from '../src/app.js';
import { requireRole } from '../src/middleware/auth.js';
import type { AuthRequest } from '../src/types.js';

describe('HTTP API foundation', () => {
  it('returns a healthy response from the public health endpoint', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.data.status).toBe('ok');
  });

  it('rejects unauthenticated access to protected API routes', async () => {
    const response = await request(app).get('/api/v1/profile/me');
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe('UNAUTHENTICATED');
  });

  it('returns 403 when a student requests an administrator-only route', async () => {
    const testApp = express();
    testApp.get('/admin-only', (req, _res, next) => {
      (req as AuthRequest).profile = { id: 'student-1', full_name: 'Avery Morgan', email: 'avery@example.edu', role: 'student', is_active: true, must_change_password: false, roll_number: null };
      next();
    }, requireRole('admin'), (_req, res) => res.json({ data: 'allowed' }));
    const response = await request(testApp).get('/admin-only');
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('FORBIDDEN');
  });
});
