import { BadRequestException, Body, Controller, Get, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RequestContext } from '../common/types/request-context';
import { AiTopUpDto } from './ai-top-up.dto';
import { AiWalletService } from './ai-wallet.service';

@ApiTags('ai-wallet')
@ApiBearerAuth()
@Controller('ai/wallet')
export class AiWalletController {
  constructor(private readonly wallet: AiWalletService) {}

  @Get()
  balance(@Req() request: RequestContext) {
    const userId = request.user?.id;
    if (!userId) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.wallet.balance(userId);
  }

  @Post('top-ups')
  topUp(@Req() request: RequestContext, @Body() body: AiTopUpDto) {
    const userId = request.user?.id;
    if (!userId) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.wallet.createTopUp(userId, body.amount);
  }
}
