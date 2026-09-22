import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { CustomersController } from './customers.controller';
import { CustomersService } from './customers.service';

/**
 * customers — implemented in a later mission. Kept as an explicit module so the
 * application graph mirrors docs/architecture.md from day one.
 */
@Module({
  imports: [SupabaseModule],
  controllers: [CustomersController],
  providers: [CustomersService],
})
export class CustomersModule {}
