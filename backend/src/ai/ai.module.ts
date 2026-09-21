import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { AiWalletService } from './ai-wallet.service';

/**
 * ai — implemented in a later mission. Kept as an explicit module so the
 * application graph mirrors docs/architecture.md from day one.
 */
@Module({
  imports: [SupabaseModule],
  providers: [AiWalletService],
  exports: [AiWalletService],
})
export class AiModule {}
