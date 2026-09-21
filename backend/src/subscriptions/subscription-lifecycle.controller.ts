import { BadRequestException, Body, Controller, Headers, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RequestContext } from '../common/types/request-context';
import { SubscriptionLifecycleService } from './subscription-lifecycle.service';
import { SubscriptionRenewalDto } from './subscription-renewal.dto';
import { StartSubscriptionDto } from './start-subscription.dto';

@ApiTags('subscriptions')
@ApiBearerAuth()
@Controller('subscriptions/lifecycle')
export class SubscriptionLifecycleController {
  constructor(private readonly lifecycle: SubscriptionLifecycleService) {}

  @Post()
  start(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: StartSubscriptionDto,
  ) {
    const userId = request.user?.id;
    if (!userId) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.lifecycle.start(userId, workspaceId, body);
  }

  @Post('expire-due')
  expireDue() {
    return this.lifecycle.expireDue();
  }

  @Post('renew')
  renew(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: SubscriptionRenewalDto,
  ) {
    const userId = request.user?.id;
    if (!userId) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.lifecycle.renew(userId, workspaceId, body.subscriptionId);
  }
}
