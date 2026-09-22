import { AppConfigService } from '../config/app-config.service';
import { SupabaseService } from '../supabase/supabase.service';
import { AppTokenService } from './app-token.service';
import { EmailOtpService } from './email-otp.service';

describe('EmailOtpService', () => {
  const secret = 'test-secret-with-at-least-32-characters';
  const config = {
    get: jest.fn((key: string) => {
      if (key === 'RESEND_API_KEY') return 'resend-test-key';
      if (key === 'EMAIL_FROM') return 'DEFACT FACILE <no-reply@example.com>';
      if (key === 'AUTH_JWT_SECRET') return secret;
      if (key === 'SUPABASE_JWT_SECRET') return secret;
      return undefined;
    }),
  } as unknown as AppConfigService;
  const tokens = {
    issue: jest.fn().mockReturnValue('app-token'),
  } as unknown as AppTokenService;

  let recentOtp: unknown;
  let insertedOtp: Record<string, unknown> | undefined;
  let deletedOtp = false;
  let rpcResult: unknown;
  let user: Record<string, unknown> | null;
  let createUser: jest.Mock;
  let service: EmailOtpService;

  beforeEach(() => {
    recentOtp = null;
    insertedOtp = undefined;
    deletedOtp = false;
    rpcResult = 'verified';
    user = null;
    createUser = jest.fn().mockResolvedValue({
      data: { user: { id: 'user-id', user_metadata: {} } },
      error: null,
    });

    const recentQuery = {
      select: jest.fn().mockReturnThis(),
      eq: jest.fn().mockReturnThis(),
      is: jest.fn().mockReturnThis(),
      order: jest.fn().mockReturnThis(),
      limit: jest.fn().mockReturnThis(),
      maybeSingle: jest.fn().mockImplementation(async () => ({ data: recentOtp, error: null })),
    };
    const deleteQuery = {
      eq: jest.fn().mockReturnThis(),
      then: (resolve: (value: unknown) => unknown) =>
        Promise.resolve({ error: null }).then(resolve),
    };
    const admin = {
      from: jest.fn((table: string) => {
        if (table === 'email_login_otps') {
          return {
            select: jest.fn().mockReturnValue(recentQuery),
            insert: jest.fn((value: Record<string, unknown>) => {
              insertedOtp = value;
              return Promise.resolve({ error: null });
            }),
            delete: jest.fn(() => {
              deletedOtp = true;
              return deleteQuery;
            }),
          };
        }

        const userQuery = {
          select: jest.fn().mockReturnThis(),
          eq: jest.fn().mockReturnThis(),
          maybeSingle: jest.fn().mockResolvedValue({ data: user, error: null }),
        };
        return userQuery;
      }),
      rpc: jest.fn().mockImplementation(async () => ({ data: rpcResult, error: null })),
      auth: { admin: { createUser } },
    };

    service = new EmailOtpService(config, { admin } as unknown as SupabaseService, tokens);
    global.fetch = jest.fn().mockResolvedValue({ ok: true });
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('generates a six-digit code and sends it without a link', async () => {
    await service.requestCode(' User@Example.com ');

    expect(insertedOtp).toMatchObject({ email: 'user@example.com' });
    expect(insertedOtp?.code_hash).toHaveLength(64);
    expect(global.fetch).toHaveBeenCalledWith(
      'https://api.resend.com/emails',
      expect.objectContaining({
        body: expect.stringContaining('Votre code de connexion DEFACT FACILE'),
      }),
    );
    const body = JSON.parse((global.fetch as jest.Mock).mock.calls[0][1].body as string) as {
      html: string;
    };
    expect(body.html).toMatch(/\b\d{6}\b/);
    expect(body.html).not.toContain('ConfirmationURL');
    expect(body.html).not.toContain('http://');
    expect(body.html).not.toContain('https://');
  });

  it('rejects a resend during the cooldown', async () => {
    recentOtp = { created_at: new Date().toISOString() };
    await expect(service.requestCode('user@example.com')).rejects.toThrow(
      'Attends quelques secondes',
    );
  });

  it('issues an application token after consuming a valid code', async () => {
    user = {
      id: 'user-id',
      email: 'user@example.com',
      full_name: 'User',
      avatar_url: null,
    };

    await expect(service.verifyCode('USER@example.com', '123456')).resolves.toEqual({
      accessToken: 'app-token',
      user: {
        id: 'user-id',
        email: 'user@example.com',
        fullName: 'User',
        avatarUrl: null,
      },
    });
    expect(tokens.issue).toHaveBeenCalledWith('user-id', 'user@example.com');
  });

  it.each([
    ['expired', 'Ce code a expiré.'],
    ['invalid', 'Code de connexion invalide.'],
    ['too_many_attempts', 'Trop de tentatives pour ce code.'],
  ])('maps %s verification results to a safe error', async (result, message) => {
    rpcResult = result;
    await expect(service.verifyCode('user@example.com', '123456')).rejects.toThrow(message);
  });

  it('removes a code when Resend rejects the message', async () => {
    (global.fetch as jest.Mock).mockResolvedValue({ ok: false });

    await expect(service.requestCode('user@example.com')).rejects.toThrow(
      'Impossible d’envoyer le code',
    );
    expect(deletedOtp).toBe(true);
  });
});
