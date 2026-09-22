import { IsOptional, IsString, MaxLength } from 'class-validator';

export class CustomerQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}
