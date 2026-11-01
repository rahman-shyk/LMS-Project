import { z } from 'zod';
export const uuid = z.string().uuid();
export const pagination = z.object({ page: z.coerce.number().int().min(1).default(1), pageSize: z.coerce.number().int().min(1).max(100).default(20) });
export const createUserSchema = z.object({ fullName: z.string().trim().min(1).max(120), email: z.email(), role: z.enum(['admin','teacher','student']), temporaryPassword: z.string().min(8), rollNumber: z.string().trim().max(32).optional() });
export const courseSchema = z.object({ code: z.string().trim().min(1).max(24), title: z.string().trim().min(1).max(160), description: z.string().max(5000).default(''), teacherId: uuid });
export const announcementSchema = z.object({ courseId: uuid.nullable(), title: z.string().trim().min(1).max(180), body: z.string().trim().min(1).max(10000), isPinned: z.boolean().default(false) });
export const complaintSchema = z.object({ category: z.enum(['academic','technical','facility','conduct','other']), subject: z.string().trim().min(3).max(180), description: z.string().trim().min(5).max(10000), attachmentPath: z.string().trim().min(1).max(500).optional() });
export const chatSchema = z.object({ courseId: uuid, body: z.string().trim().min(1).max(2000) });
export const assignmentSchema = z.object({ courseId: uuid, title: z.string().trim().min(1).max(180), instructions: z.string().max(10000).default(''), dueAt: z.iso.datetime().nullable().optional(), maxMarks: z.number().positive(), allowLate: z.boolean().default(false) });
