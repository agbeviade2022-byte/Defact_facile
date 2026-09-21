import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { GeniusPayWebhookController } from './geniuspay-webhook.controller';
import { GeniusPayWebhookService } from './geniuspay-webhook.service';
import { GeniusPayPaymentController } from './geniuspay-payment.controller';
import { GeniusPayService } from './geniuspay.service';
import { PaymentsController } from './payments.controller';
import { PaymentsService } from './payments.service';

@Module({
  imports: [SupabaseModule],
  controllers: [GeniusPayWebhookController, GeniusPayPaymentController, PaymentsController],
  providers: [GeniusPayWebhookService, GeniusPayService, PaymentsService],
  exports: [GeniusPayService],
})
export class PaymentsModule {}
