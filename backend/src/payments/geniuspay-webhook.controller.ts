import { BadRequestException, Controller, Headers, Post, Req } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { Request } from 'express';
import { Public } from '../common/decorators/public.decorator';
import { GeniusPayWebhookService } from './geniuspay-webhook.service';

@ApiTags('payments')
@Controller('payments/geniuspay')
export class GeniusPayWebhookController {
  constructor(private readonly webhook: GeniusPayWebhookService) {}

  @Public()
  @Post('webhook')
  handle(
    @Req() request: Request & { rawBody?: Buffer },
    @Headers('x-webhook-signature') signature?: string,
    @Headers('x-webhook-timestamp') timestamp?: string,
    @Headers('x-webhook-event') event?: string,
  ) {
    const rawBody = request.rawBody?.toString('utf8');
    if (!rawBody) throw new BadRequestException('Raw webhook body is required.');
    return this.webhook.handle(rawBody, signature, timestamp, event);
  }
}
