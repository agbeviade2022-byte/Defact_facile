import { Controller, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { SubscriptionLifecycleService } from './subscription-lifecycle.service';

@ApiTags('subscriptions')
@ApiBearerAuth()
@Controller('subscriptions/lifecycle')
export class SubscriptionLifecycleController {
  constructor(private readonly lifecycle: SubscriptionLifecycleService) {}

  @Post('expire-due')
  expireDue() {
    return this.lifecycle.expireDue();
  }
}
