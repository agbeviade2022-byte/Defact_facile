import { IsIn } from 'class-validator';

export class AiTopUpDto {
  @IsIn([1000, 5000, 10000, 25000])
  amount!: 1000 | 5000 | 10000 | 25000;
}
