import { IsIn, IsInt, IsOptional, IsString, Min } from 'class-validator';

export class AiGatewayDto {
  @IsString()
  action!: string;

  @IsString()
  prompt!: string;

  @IsOptional()
  @IsString()
  model?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  maxTokens?: number;

  @IsOptional()
  @IsIn(['CLAUDE', 'OPENAI'])
  preferredProvider?: 'CLAUDE' | 'OPENAI';
}
