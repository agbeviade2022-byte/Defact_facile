import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { SubscriptionLifecycleController } from './subscription-lifecycle.controller';
import { SubscriptionLifecycleService } from './subscription-lifecycle.service';

/**
 * subscriptions — implemented in a later mission. Kept as an explicit module so the
 * application graph mirrors docs/architecture.md from day one.
 */
@Module({
  imports: [SupabaseModule],
  controllers: [SubscriptionLifecycleController],
  providers: [SubscriptionLifecycleService],
})
export class SubscriptionsModule {}
