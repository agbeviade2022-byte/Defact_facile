import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { AnthropicProvider } from './anthropic.provider';
import { AiGatewayService } from './ai-gateway.service';
import { AiWalletService } from './ai-wallet.service';
import { OpenAiProvider } from './openai.provider';
import { AiGatewayController } from './ai-gateway.controller';
import { AiWalletController } from './ai-wallet.controller';
import { PaymentsModule } from '../payments/payments.module';

/**
 * ai — implemented in a later mission. Kept as an explicit module so the
 * application graph mirrors docs/architecture.md from day one.
 */
@Module({
  imports: [SupabaseModule, PaymentsModule],
  controllers: [AiGatewayController, AiWalletController],
  providers: [AiWalletService, AnthropicProvider, OpenAiProvider, AiGatewayService],
  exports: [AiWalletService, AnthropicProvider, OpenAiProvider, AiGatewayService],
})
export class AiModule {}
