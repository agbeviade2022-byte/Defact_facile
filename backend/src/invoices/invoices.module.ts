import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { InvoicesController } from './invoices.controller';
import { InvoicesService } from './invoices.service';

@Module({
  imports: [SupabaseModule],
  controllers: [InvoicesController],
  providers: [InvoicesService],
})
export class InvoicesModule {}
