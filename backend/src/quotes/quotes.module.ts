import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { QuotesController } from './quotes.controller';
import { QuotesService } from './quotes.service';

/**
 * quotes — implemented in a later mission. Kept as an explicit module so the
 * application graph mirrors docs/architecture.md from day one.
 */
@Module({
  imports: [SupabaseModule],
  controllers: [QuotesController],
  providers: [QuotesService],
})
export class QuotesModule {}
