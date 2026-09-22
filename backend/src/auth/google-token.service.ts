import { Injectable, UnauthorizedException } from '@nestjs/common';
import {
  createPublicKey,
  createVerify,
  KeyObject,
  JsonWebKey as NodeJsonWebKey,
} from 'node:crypto';
import { AppConfigService } from '../config/app-config.service';

interface GoogleKey {
  kid: string;
  kty: string;
  n: string;
  e: string;
  alg?: string;
  use?: string;
}

interface GoogleClaims {
  sub: string;
  email: string;
  email_verified?: boolean | string;
  name?: string;
  picture?: string;
  aud: string | string[];
  iss: string;
  exp: number;
}

interface GoogleKeysResponse {
  keys: GoogleKey[];
}

@Injectable()
export class GoogleTokenService {
  private keys: GoogleKey[] = [];
  private keysExpiresAt = 0;

  constructor(private readonly config: AppConfigService) {}

  async verify(idToken: string): Promise<GoogleClaims> {
    const [encodedHeader, encodedPayload, encodedSignature] = idToken.split('.');
    if (!encodedHeader || !encodedPayload || !encodedSignature) {
      throw new UnauthorizedException('Jeton Google invalide.');
    }

    let header: { alg?: string; kid?: string };
    let claims: GoogleClaims;
    try {
      header = JSON.parse(Buffer.from(encodedHeader, 'base64url').toString('utf8')) as {
        alg?: string;
        kid?: string;
      };
      claims = JSON.parse(
        Buffer.from(encodedPayload, 'base64url').toString('utf8'),
      ) as GoogleClaims;
    } catch {
      throw new UnauthorizedException('Jeton Google invalide.');
    }

    if (header.alg !== 'RS256' || !header.kid) {
      throw new UnauthorizedException('Signature Google invalide.');
    }

    const key = await this.findKey(header.kid);
    const verifier = createVerify('RSA-SHA256');
    verifier.update(`${encodedHeader}.${encodedPayload}`);
    verifier.end();
    const signature = Buffer.from(encodedSignature, 'base64url');
    if (!verifier.verify(key, signature)) {
      throw new UnauthorizedException('Signature Google invalide.');
    }

    const configuredClientId = this.config.get('GOOGLE_WEB_CLIENT_ID');
    const audience = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
    const now = Math.floor(Date.now() / 1000);
    if (
      !configuredClientId ||
      !audience.includes(configuredClientId) ||
      !['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss) ||
      claims.exp <= now ||
      !claims.sub ||
      !claims.email ||
      (claims.email_verified !== true && claims.email_verified !== 'true')
    ) {
      throw new UnauthorizedException('Identité Google invalide.');
    }
    return claims;
  }

  private async findKey(kid: string): Promise<KeyObject> {
    if (Date.now() >= this.keysExpiresAt) await this.refreshKeys();
    const key = this.keys.find((candidate) => candidate.kid === kid);
    if (!key) {
      await this.refreshKeys();
      const refreshedKey = this.keys.find((candidate) => candidate.kid === kid);
      if (!refreshedKey) throw new UnauthorizedException('Clé Google inconnue.');
      return createPublicKey({
        key: refreshedKey as unknown as NodeJsonWebKey,
        format: 'jwk',
      });
    }
    return createPublicKey({
      key: key as unknown as NodeJsonWebKey,
      format: 'jwk',
    });
  }

  private async refreshKeys(): Promise<void> {
    const response = await fetch('https://www.googleapis.com/oauth2/v3/certs');
    if (!response.ok) throw new UnauthorizedException('Vérification Google indisponible.');
    const body = (await response.json()) as GoogleKeysResponse;
    this.keys = body.keys;
    this.keysExpiresAt = Date.now() + 60 * 60 * 1000;
  }
}
