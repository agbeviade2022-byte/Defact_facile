import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Env } from './env.schema';

@Injectable()
export class AppConfigService {
  constructor(private readonly config: ConfigService<Env, true>) {}

  get<K extends keyof Env>(key: K): Env[K] {
    return this.config.get(key, { infer: true });
  }

  get env() {
    return this.get('NODE_ENV');
  }

  get isProduction() {
    return this.env === 'production';
  }

  get corsOrigins(): string[] | boolean {
    const raw = this.get('CORS_ORIGINS');
    if (raw === '*') return true;
    return raw
      .split(',')
      .map((o) => o.trim())
      .filter(Boolean);
  }
}
