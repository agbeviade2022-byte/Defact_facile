import {
  HttpException,
  HttpStatus,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { createHmac, randomInt } from 'node:crypto';
import { SupabaseService } from '../supabase/supabase.service';
import { AppConfigService } from '../config/app-config.service';
import { AppTokenService } from './app-token.service';

const OTP_LIFETIME_MS = 10 * 60 * 1000;
const OTP_RESEND_COOLDOWN_MS = 60 * 1000;

interface OtpRow {
  created_at: string;
}

interface UserRow {
  id: string;
  email: string | null;
  full_name: string | null;
  avatar_url: string | null;
}

@Injectable()
export class EmailOtpService {
  constructor(
    private readonly config: AppConfigService,
    private readonly supabase: SupabaseService,
    private readonly tokens: AppTokenService,
  ) {}

  async requestCode(emailInput: string): Promise<void> {
    const email = this.normalizeEmail(emailInput);
    const { data: recent, error: recentError } = await this.supabase.admin
      .from('email_login_otps')
      .select('created_at')
      .eq('email', email)
      .is('consumed_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle<OtpRow>();

    if (recentError) {
      throw new ServiceUnavailableException('Le service de connexion est indisponible.');
    }

    if (recent && Date.now() - Date.parse(recent.created_at) < OTP_RESEND_COOLDOWN_MS) {
      throw new HttpException(
        'Attends quelques secondes avant de redemander un code.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const code = String(randomInt(0, 1_000_000)).padStart(6, '0');
    const { error: insertError } = await this.supabase.admin.from('email_login_otps').insert({
      email,
      code_hash: this.hashCode(code),
      expires_at: new Date(Date.now() + OTP_LIFETIME_MS).toISOString(),
    });

    if (insertError) {
      throw new ServiceUnavailableException('Impossible de préparer le code de connexion.');
    }

    try {
      await this.sendEmail(email, code);
    } catch (error) {
      await this.supabase.admin
        .from('email_login_otps')
        .delete()
        .eq('email', email)
        .eq('code_hash', this.hashCode(code));
      throw error;
    }
  }

  async verifyCode(emailInput: string, code: string) {
    const email = this.normalizeEmail(emailInput);
    const result = await this.supabase.admin.rpc('consume_email_login_otp', {
      p_email: email,
      p_code_hash: this.hashCode(code),
    });

    if (result.error) {
      throw new ServiceUnavailableException('Le service de connexion est indisponible.');
    }

    switch (result.data) {
      case 'verified':
        break;
      case 'expired':
        throw new UnauthorizedException('Ce code a expiré.');
      case 'too_many_attempts':
        throw new HttpException('Trop de tentatives pour ce code.', HttpStatus.TOO_MANY_REQUESTS);
      default:
        throw new UnauthorizedException('Code de connexion invalide.');
    }

    const user = await this.findOrCreateUser(email);
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

  private async findOrCreateUser(email: string): Promise<UserRow> {
    const { data: existing, error: existingError } = await this.supabase.admin
      .from('users')
      .select('id, email, full_name, avatar_url')
      .eq('email', email)
      .maybeSingle<UserRow>();

    if (existingError) {
      throw new ServiceUnavailableException('Impossible de charger le compte.');
    }
    if (existing) return existing;

    const { data: created, error: createError } = await this.supabase.admin.auth.admin.createUser({
      email,
      email_confirm: true,
      password: randomInt(0, 2 ** 31).toString(36) + randomInt(0, 2 ** 31).toString(36),
      user_metadata: { provider: 'email_otp' },
    });

    if (created.user) {
      return {
        id: created.user.id,
        email,
        full_name: created.user.user_metadata?.full_name ?? null,
        avatar_url: created.user.user_metadata?.avatar_url ?? null,
      };
    }

    if (createError) {
      const { data: concurrentUser } = await this.supabase.admin
        .from('users')
        .select('id, email, full_name, avatar_url')
        .eq('email', email)
        .maybeSingle<UserRow>();
      if (concurrentUser) return concurrentUser;
    }

    throw new ServiceUnavailableException('Impossible de créer le compte.');
  }

  private async sendEmail(email: string, code: string): Promise<void> {
    const apiKey = this.config.get('RESEND_API_KEY');
    if (!apiKey) {
      throw new ServiceUnavailableException('Le service e-mail n’est pas configuré.');
    }

    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: this.config.get('EMAIL_FROM'),
        to: [email],
        subject: 'Votre code de connexion DEFACT FACILE',
        html: this.emailHtml(code),
      }),
    });

    if (!response.ok) {
      throw new ServiceUnavailableException('Impossible d’envoyer le code de connexion.');
    }
  }

  private emailHtml(code: string): string {
    return `
      <div style="background:#171717;padding:32px 16px;font-family:Arial,sans-serif;color:#f5f5f5">
        <div style="max-width:520px;margin:0 auto;background:#242424;border-radius:16px;overflow:hidden">
          <div style="background:#16a34a;padding:28px;text-align:center">
            <h1 style="margin:0;color:#fff;font-size:30px">DEFACT FACILE</h1>
          </div>
          <div style="padding:32px">
            <h2 style="margin-top:0">Code OTP de connexion</h2>
            <p>Utilisez ce code pour finaliser votre connexion à DEFACT FACILE :</p>
            <div style="margin:28px 0;padding:18px;text-align:center;background:#303030;border-radius:12px;font-size:36px;letter-spacing:10px;font-weight:700">${code}</div>
            <p style="color:#c7c7c7">Ce code expire dans 10 minutes et n’est valable qu’une seule fois.</p>
            <p style="color:#c7c7c7">Si vous n’êtes pas à l’origine de cette tentative, ignorez ce message.</p>
          </div>
          <div style="padding:18px;text-align:center;background:#202020;color:#aaa">DEFACT FACILE — Connexion sécurisée</div>
        </div>
      </div>
    `;
  }

  private hashCode(code: string): string {
    const secret = this.config.get('AUTH_JWT_SECRET') ?? this.config.get('SUPABASE_JWT_SECRET');
    return createHmac('sha256', secret).update(code).digest('hex');
  }

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
  }
}
