import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { PlanController } from './plan.controller';
import { PlanService } from './plan.service';

@Module({
  imports: [SupabaseModule],
  controllers: [PlanController],
  providers: [PlanService],
})
export class PlansModule {}
