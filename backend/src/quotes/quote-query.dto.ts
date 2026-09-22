import { IsOptional, IsString, MaxLength } from 'class-validator';

export class QuoteQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}
