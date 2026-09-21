import { validateEnv } from './env.schema';

const validEnv = {
  DATABASE_URL: 'postgresql://postgres:postgres@localhost:54322/postgres',
  SUPABASE_URL: 'http://localhost:54321',
  SUPABASE_ANON_KEY: 'anon',
  SUPABASE_SERVICE_ROLE_KEY: 'service',
  SUPABASE_JWT_SECRET: 'super-secret-jwt-token-with-at-least-32-characters',
};

describe('validateEnv', () => {
  it('applies defaults for optional values', () => {
    const env = validateEnv(validEnv);
    expect(env.NODE_ENV).toBe('development');
    expect(env.PORT).toBe(3000);
    expect(env.API_PREFIX).toBe('api/v1');
    expect(env.AI_DEFAULT_PROVIDER).toBe('anthropic');
  });

  it('coerces numeric strings', () => {
    const env = validateEnv({ ...validEnv, PORT: '8080', RATE_LIMIT_MAX: '10' });
    expect(env.PORT).toBe(8080);
    expect(env.RATE_LIMIT_MAX).toBe(10);
  });

  it('rejects a missing service role key', () => {
    const { SUPABASE_SERVICE_ROLE_KEY: _omitted, ...rest } = validEnv;
    void _omitted;
    expect(() => validateEnv(rest)).toThrow(/SUPABASE_SERVICE_ROLE_KEY/);
  });

  it('rejects an unknown environment name', () => {
    expect(() => validateEnv({ ...validEnv, NODE_ENV: 'prod' })).toThrow(/NODE_ENV/);
  });

  it('treats empty optional values as unset', () => {
    const env = validateEnv({ ...validEnv, FNE_API_URL: '', RESEND_API_KEY: '' });
    expect(env.FNE_API_URL).toBeUndefined();
    expect(env.RESEND_API_KEY).toBeUndefined();
  });

  it('rejects wildcard CORS in production', () => {
    expect(() => validateEnv({ ...validEnv, NODE_ENV: 'production' })).toThrow(/CORS_ORIGINS/);
    const env = validateEnv({
      ...validEnv,
      NODE_ENV: 'production',
      CORS_ORIGINS: 'https://app.defactfacile.com',
    });
    expect(env.CORS_ORIGINS).toBe('https://app.defactfacile.com');
  });
});
