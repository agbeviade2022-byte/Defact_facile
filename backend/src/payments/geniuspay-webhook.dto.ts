import { IsIn, IsOptional, IsString, IsUUID, IsNumber, Min } from 'class-validator';

export class GeniusPayWebhookDto {
  @IsString()
  providerReference!: string;

  @IsUUID()
  userId!: string;

  @IsNumber()
  @Min(1)
  amount!: number;

  @IsString()
  currency!: string;

  @IsIn(['PENDING', 'SUCCEEDED', 'FAILED', 'CANCELLED'])
  status!: 'PENDING' | 'SUCCEEDED' | 'FAILED' | 'CANCELLED';

  @IsIn(['SUBSCRIPTION', 'AI_TOP_UP'])
  kind!: 'SUBSCRIPTION' | 'AI_TOP_UP';

  @IsOptional()
  @IsUUID()
  subscriptionId?: string;
}
