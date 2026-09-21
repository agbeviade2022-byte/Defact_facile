import { BadRequestException, Controller, Headers, Post, Body, Req } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { SupabaseService } from '../supabase/supabase.service';
import { RequestContext } from '../common/types/request-context';
import { AiGatewayDto } from './ai-gateway.dto';
import { AiGatewayService } from './ai-gateway.service';

@ApiTags('ai')
@ApiBearerAuth()
@Controller('ai')
export class AiGatewayController {
  constructor(
    private readonly gateway: AiGatewayService,
    private readonly supabase: SupabaseService,
  ) {}

  @Post('complete')
  async complete(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: AiGatewayDto,
  ) {
    const userId = request.user?.id;
    if (!userId) throw new BadRequestException('Identité utilisateur indisponible.');
    if (!workspaceId) throw new BadRequestException('X-Workspace-Id est requis.');
    await this.assertWorkspaceAccess(userId, workspaceId);

    const { data, error } = await this.supabase.admin
      .from('ai_action_costs')
      .select('credits')
      .eq('action', body.action)
      .maybeSingle();
    if (error) throw new BadRequestException('Coût IA indisponible.');
    if (!data) throw new BadRequestException('Action IA inconnue.');

    return this.gateway.complete({
      ...body,
      userId,
      action: body.action,
      quotaCost: data.credits,
      idempotencyKey: request.headers['x-idempotency-key']?.toString() ?? randomUUID(),
    });
  }

  private async assertWorkspaceAccess(userId: string, workspaceId: string): Promise<void> {
    const personal = await this.supabase.admin
      .from('personal_workspaces')
      .select('id')
      .eq('id', workspaceId)
      .eq('user_id', userId)
      .maybeSingle();
    if (personal.data) return;

    const organization = await this.supabase.admin
      .from('organization_members')
      .select('id')
      .eq('organization_id', workspaceId)
      .eq('user_id', userId)
      .eq('status', 'ACTIVE')
      .maybeSingle();
    if (!organization.data) throw new BadRequestException('Workspace inaccessible.');
  }
}
