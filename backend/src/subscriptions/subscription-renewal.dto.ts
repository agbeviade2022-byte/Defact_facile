import { IsUUID } from 'class-validator';

export class SubscriptionRenewalDto {
  @IsUUID()
  subscriptionId!: string;
}
