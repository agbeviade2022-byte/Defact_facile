import { Module } from '@nestjs/common';
import { AiService } from './ai.service';
import { AiController } from './ai.controller';
import { CreditsModule } from './credits/credits.module';
import { UsageModule } from './usage/usage.module';
import { GuardModule } from './guard/guard.module';
import { WalletModule } from './wallet/wallet.module';
import { GatewayModule } from './gateway/gateway.module';

@Module({
  imports: [CreditsModule, UsageModule, GuardModule, WalletModule, GatewayModule],
  providers: [AiService],
  controllers: [AiController],
  exports: [AiService, CreditsModule, UsageModule, GuardModule, WalletModule, GatewayModule],
})
export class AiModule {}