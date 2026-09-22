import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class CreateInvoiceFromQuoteDto {
  @IsUUID()
  quoteId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;
}

export class InvoiceQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}
