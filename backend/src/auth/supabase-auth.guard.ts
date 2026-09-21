import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { SupabaseService } from '../supabase/supabase.service';
import { IS_PUBLIC_KEY } from '../common/decorators/public.decorator';
import { RequestContext } from '../common/types/request-context';

@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly supabase: SupabaseService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest<RequestContext>();
    const authorization = request.headers.authorization;
    if (!authorization?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Authentification requise.');
    }

    const accessToken = authorization.slice('Bearer '.length).trim();
    if (!accessToken) throw new UnauthorizedException('Jeton manquant.');

    const { data, error } = await this.supabase.admin.auth.getUser(accessToken);
    if (error || !data.user) throw new UnauthorizedException('Jeton invalide.');

    request.user = {
      id: data.user.id,
      email: data.user.email ?? null,
      accessToken,
    };
    return true;
  }
}
