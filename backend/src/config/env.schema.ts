import { z } from 'zod';

export const APP_ENVIRONMENTS = ['development', 'staging', 'production', 'test'] as const;
export type AppEnvironment = (typeof APP_ENVIRONMENTS)[number];

export const envSchema = z
  .object({
    NODE_ENV: z.enum(APP_ENVIRONMENTS).default('development'),
    PORT: z.coerce.number().int().positive().default(3000),
    API_PREFIX: z.string().default('api/v1'),
    CORS_ORIGINS: z
      .string()
      .default('http://localhost:3000,http://localhost:5000,http://localhost:8080'),
    LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'log', 'debug', 'verbose']).default('log'),

    DATABASE_URL: z.string().url(),
    SUPABASE_URL: z.string().url(),
    SUPABASE_ANON_KEY: z.string().min(1),
    SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
    SUPABASE_JWT_SECRET: z.string().min(16),

    RESEND_API_KEY: z.string().optional(),
    EMAIL_FROM: z.string().default('DEFACT FACILE <no-reply@defactfacile.com>'),

    ANTHROPIC_API_KEY: z.string().optional(),
    OPENAI_API_KEY: z.string().optional(),
    AI_DEFAULT_PROVIDER: z.enum(['anthropic', 'openai']).default('anthropic'),
    GENIUSPAY_WEBHOOK_SECRET: z.string().optional(),

    WHATSAPP_API_KEY: z.string().optional(),
    FNE_API_URL: z.string().url().optional(),
    FNE_API_KEY: z.string().optional(),

    RATE_LIMIT_TTL_SECONDS: z.coerce.number().int().positive().default(60),
    RATE_LIMIT_MAX: z.coerce.number().int().positive().default(120),
  })
  .superRefine((env, ctx) => {
    if (env.NODE_ENV === 'production' && env.CORS_ORIGINS.trim() === '*') {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['CORS_ORIGINS'],
        message: 'must be an explicit comma-separated list of origins in production',
      });
    }
  });

export type Env = z.infer<typeof envSchema>;

export function validateEnv(raw: Record<string, unknown>): Env {
  // Empty values (e.g. `KEY=` copied from .env.example) count as unset.
  const cleaned = Object.fromEntries(
    Object.entries(raw).filter(([, v]) => !(typeof v === 'string' && v.trim() === '')),
  );
  if (cleaned.NODE_ENV === 'production' && !cleaned.CORS_ORIGINS) {
    throw new Error(
      'Invalid environment configuration:\n  - CORS_ORIGINS: must be explicitly configured in production',
    );
  }
  const result = envSchema.safeParse(cleaned);
  if (!result.success) {
    const issues = result.error.issues
      .map((i) => `  - ${i.path.join('.')}: ${i.message}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${issues}`);
  }
  return result.data;
}
