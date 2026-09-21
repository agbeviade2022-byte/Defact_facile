import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { GeniusPayWebhookController } from './geniuspay-webhook.controller';
import { GeniusPayWebhookService } from './geniuspay-webhook.service';
import { GeniusPayPaymentController } from './geniuspay-payment.controller';
import { GeniusPayService } from './geniuspay.service';

@Module({
  imports: [SupabaseModule],
  controllers: [GeniusPayWebhookController, GeniusPayPaymentController],
  providers: [GeniusPayWebhookService, GeniusPayService],
  exports: [GeniusPayService],
})
export class PaymentsModule {}
