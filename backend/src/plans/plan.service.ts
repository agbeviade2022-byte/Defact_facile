import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';

export interface PlanSummary {
  id: string;
  code: string;
  name: string;
  description: string | null;
  audience: 'PERSONAL' | 'ORGANIZATION' | 'BOTH';
  priceMonthly: number;
  priceYearly: number;
  currency: string;
  aiCreditsMonthly: number;
  limits: Record<string, unknown>;
  features: Record<string, unknown>;
}

@Injectable()
export class PlanService {
  constructor(private readonly supabase: SupabaseService) {}

  async list(): Promise<PlanSummary[]> {
    const { data, error } = await this.supabase.admin
      .from('plans')
      .select(
        'id, code, name, description, audience, price_monthly, price_yearly, currency, ai_credits_monthly, limits, features',
      )
      .eq('is_active', true)
      .order('price_monthly', { ascending: true });

    if (error) throw new InternalServerErrorException('Forfaits indisponibles.');

    return (data ?? []).map((plan) => ({
      id: plan.id,
      code: plan.code,
      name: plan.name,
      description: plan.description,
      audience: plan.audience,
      priceMonthly: Number(plan.price_monthly),
      priceYearly: Number(plan.price_yearly),
      currency: plan.currency.trim(),
      aiCreditsMonthly: plan.ai_credits_monthly,
      limits: this.asRecord(plan.limits),
      features: this.asRecord(plan.features),
    }));
  }

  private asRecord(value: unknown): Record<string, unknown> {
    return value !== null && typeof value === 'object' && !Array.isArray(value)
      ? (value as Record<string, unknown>)
      : {};
  }
}
