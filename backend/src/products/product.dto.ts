import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateProductDto {
  @IsIn(['PRODUCT', 'SERVICE'])
  kind!: 'PRODUCT' | 'SERVICE';

  @IsString()
  @MinLength(2)
  @MaxLength(160)
  name!: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  sku?: string;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  unit?: string;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  salePrice?: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  taxRate?: number;

  @IsOptional()
  @IsBoolean()
  trackStock?: boolean;
}

export class ProductQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(100)
  search?: string;
}
