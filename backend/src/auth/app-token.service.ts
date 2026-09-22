import { Injectable, UnauthorizedException } from '@nestjs/common';
import { createHmac, timingSafeEqual } from 'node:crypto';
import { AppConfigService } from '../config/app-config.service';

interface AppTokenClaims {
  sub: string;
  email: string | null;
  iat: number;
  exp: number;
  iss: 'defact-facile';
  aud: 'defact-facile-api';
}

function encode(value: object): string {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function decode<T>(value: string): T {
  return JSON.parse(Buffer.from(value, 'base64url').toString('utf8')) as T;
}

@Injectable()
export class AppTokenService {
  constructor(private readonly config: AppConfigService) {}

  issue(userId: string, email: string | null): string {
    const now = Math.floor(Date.now() / 1000);
    const header = encode({ alg: 'HS256', typ: 'JWT' });
    const payload = encode({
      sub: userId,
      email,
      iat: now,
      exp: now + 60 * 60 * 24 * 30,
      iss: 'defact-facile',
      aud: 'defact-facile-api',
    } satisfies AppTokenClaims);
    const unsigned = `${header}.${payload}`;
    const signature = createHmac('sha256', this.secret()).update(unsigned).digest('base64url');
    return `${unsigned}.${signature}`;
  }

  verify(token: string): AppTokenClaims {
    const parts = token.split('.');
    if (parts.length !== 3) throw new UnauthorizedException('Jeton invalide.');

    const unsigned = `${parts[0]}.${parts[1]}`;
    const expected = createHmac('sha256', this.secret()).update(unsigned).digest();
    const actual = Buffer.from(parts[2], 'base64url');
    if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) {
      throw new UnauthorizedException('Jeton invalide.');
    }

    let claims: AppTokenClaims;
    try {
      claims = decode<AppTokenClaims>(parts[1]);
    } catch {
      throw new UnauthorizedException('Jeton invalide.');
    }

    const now = Math.floor(Date.now() / 1000);
    if (
      claims.iss !== 'defact-facile' ||
      claims.aud !== 'defact-facile-api' ||
      !claims.sub ||
      claims.exp <= now
    ) {
      throw new UnauthorizedException('Jeton expiré.');
    }
    return claims;
  }

  private secret(): string {
    return this.config.get('AUTH_JWT_SECRET') ?? this.config.get('SUPABASE_JWT_SECRET');
  }
}
