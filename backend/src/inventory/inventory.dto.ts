import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  IsNotEmpty,
} from 'class-validator';

export class StockMovementDto {
  @IsUUID()
  productId!: string;

  @IsOptional()
  @IsUUID()
  warehouseId?: string;

  @IsIn(['PURCHASE', 'ADJUSTMENT', 'RETURN'])
  type!: 'PURCHASE' | 'ADJUSTMENT' | 'RETURN';

  @IsNumber({ maxDecimalPlaces: 3 })
  @IsNotEmpty()
  quantity!: number;

  @IsOptional()
  @IsNumber({ maxDecimalPlaces: 2 })
  unitCost?: number;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
