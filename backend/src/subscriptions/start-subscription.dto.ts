import { IsIn, IsUUID } from 'class-validator';

export class StartSubscriptionDto {
  @IsUUID()
  planId!: string;

  @IsIn(['MONTHLY', 'YEARLY'])
  billingCycle!: 'MONTHLY' | 'YEARLY';
}
