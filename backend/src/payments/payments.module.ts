import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { GeniusPayWebhookController } from './geniuspay-webhook.controller';
import { GeniusPayWebhookService } from './geniuspay-webhook.service';

@Module({
  imports: [SupabaseModule],
  controllers: [GeniusPayWebhookController],
  providers: [GeniusPayWebhookService],
})
export class PaymentsModule {}
