import { IsIn, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class GeniusPayPaymentDto {
  @IsNumber()
  @Min(200)
  amount!: number;

  @IsIn(['SUBSCRIPTION', 'AI_TOP_UP'])
  kind!: 'SUBSCRIPTION' | 'AI_TOP_UP';

  @IsOptional()
  @IsUUID()
  subscriptionId?: string;

  @IsOptional()
  @IsString()
  description?: string;
}
