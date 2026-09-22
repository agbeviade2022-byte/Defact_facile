import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  IsPositive,
} from 'class-validator';

export class CreateInvoicePaymentDto {
  @IsUUID()
  invoiceId!: string;

  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  amount!: number;

  @IsIn([
    'CASH',
    'ORANGE_MONEY',
    'MTN_MOMO',
    'MOOV_MONEY',
    'WAVE',
    'BANK_TRANSFER',
    'CARD',
    'OTHER',
  ])
  method!: string;

  @IsOptional()
  @IsString()
  @MaxLength(160)
  reference?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

export class PaymentQueryDto {
  @IsOptional()
  @IsUUID()
  invoiceId?: string;
}
