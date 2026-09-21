import { UnauthorizedException } from '@nestjs/common';
import { AppConfigService } from '../config/app-config.service';
import { AppTokenService } from './app-token.service';

describe('AppTokenService', () => {
  const service = new AppTokenService({
    get: (key: 'AUTH_JWT_SECRET' | 'SUPABASE_JWT_SECRET') =>
      key === 'AUTH_JWT_SECRET' ? 'a'.repeat(32) : 'b'.repeat(32),
  } as unknown as AppConfigService);

  it('issues and verifies an application session', () => {
    const token = service.issue('user-id', 'user@example.com');

    expect(service.verify(token)).toEqual(
      expect.objectContaining({
        sub: 'user-id',
        email: 'user@example.com',
        iss: 'defact-facile',
        aud: 'defact-facile-api',
      }),
    );
  });

  it('rejects a tampered session', () => {
    const token = service.issue('user-id', null);

    expect(() => service.verify(`${token}tampered`)).toThrow(UnauthorizedException);
  });
});
