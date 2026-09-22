import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { InventoryController } from './inventory.controller';
import { InventoryService } from './inventory.service';

@Module({
  imports: [SupabaseModule],
  controllers: [InventoryController],
  providers: [InventoryService],
})
export class InventoryModule {}
