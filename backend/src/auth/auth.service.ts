import { Injectable, UnauthorizedException } from '@nestjs/common';
import { randomBytes } from 'node:crypto';
import { SupabaseService } from '../supabase/supabase.service';
import { AppTokenService } from './app-token.service';
import { GoogleTokenService } from './google-token.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly supabase: SupabaseService,
    private readonly google: GoogleTokenService,
    private readonly tokens: AppTokenService,
  ) {}

  async signInWithGoogle(idToken: string) {
    const identity = await this.google.verify(idToken);
    const email = identity.email.toLowerCase();
    const { data: existing, error: existingError } = await this.supabase.admin
      .from('users')
      .select('id, email, full_name, avatar_url')
      .eq('email', email)
      .maybeSingle();
    if (existingError) throw new UnauthorizedException('Impossible de charger le compte.');

    let user = existing;
    if (!user) {
      const { data: created, error: createError } = await this.supabase.admin.auth.admin.createUser(
        {
          email,
          email_confirm: true,
          password: randomBytes(32).toString('base64url'),
          user_metadata: {
            full_name: identity.name ?? email,
            avatar_url: identity.picture ?? null,
            provider: 'google',
          },
        },
      );
      if (createError || !created.user) {
        throw new UnauthorizedException('Impossible de créer le compte Google.');
      }
      user = {
        id: created.user.id,
        email,
        full_name: identity.name ?? email,
        avatar_url: identity.picture ?? null,
      };
    } else {
      await this.supabase.admin
        .from('users')
        .update({
          full_name: user.full_name ?? identity.name ?? email,
          avatar_url: user.avatar_url ?? identity.picture ?? null,
        })
        .eq('id', user.id);
    }

    return {
      accessToken: this.tokens.issue(user.id, user.email),
      user: {
        id: user.id,
        email: user.email,
        fullName: user.full_name,
        avatarUrl: user.avatar_url,
      },
    };
  }
}
