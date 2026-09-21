import { Body, Controller, Headers, Post } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Public } from '../common/decorators/public.decorator';
import { GeniusPayWebhookDto } from './geniuspay-webhook.dto';
import { GeniusPayWebhookService } from './geniuspay-webhook.service';

@ApiTags('payments')
@Controller('payments/geniuspay')
export class GeniusPayWebhookController {
  constructor(private readonly webhook: GeniusPayWebhookService) {}

  @Public()
  @Post('webhook')
  handle(
    @Body() payload: GeniusPayWebhookDto,
    @Headers('x-geniuspay-signature') signature?: string,
  ) {
    return this.webhook.handle(payload, signature);
  }
}
