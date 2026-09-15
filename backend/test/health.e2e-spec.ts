import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { SupabaseService } from '../src/supabase/supabase.service';

const supabaseStub = {
  admin: {
    from: () => ({
      select: () => ({
        limit: async () => ({ data: [], error: null }),
      }),
    }),
  },
};

describe('Health (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.DATABASE_URL ??= 'postgresql://postgres:postgres@localhost:54322/postgres';
    process.env.SUPABASE_URL ??= 'http://localhost:54321';
    process.env.SUPABASE_ANON_KEY ??= 'anon';
    process.env.SUPABASE_SERVICE_ROLE_KEY ??= 'service';
    process.env.SUPABASE_JWT_SECRET ??= 'super-secret-jwt-token-with-at-least-32-characters';

    const moduleRef = await Test.createTestingModule({ imports: [AppModule] })
      .overrideProvider(SupabaseService)
      .useValue(supabaseStub)
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1');
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/health returns ok', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/health').expect(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.info.database.status).toBe('up');
  });

  it('unknown routes return the standard error envelope', async () => {
    const res = await request(app.getHttpServer()).get('/api/v1/does-not-exist').expect(404);
    expect(res.body).toMatchObject({ statusCode: 404, path: '/api/v1/does-not-exist' });
    expect(typeof res.body.timestamp).toBe('string');
  });
});
