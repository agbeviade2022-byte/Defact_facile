import { BadRequestException, Body, Controller, Headers, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RequestContext } from '../common/types/request-context';
import { SubscriptionLifecycleService } from './subscription-lifecycle.service';
import { SubscriptionRenewalDto } from './subscription-renewal.dto';

@ApiTags('subscriptions')
@ApiBearerAuth()
@Controller('subscriptions/lifecycle')
export class SubscriptionLifecycleController {
  constructor(private readonly lifecycle: SubscriptionLifecycleService) {}

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
