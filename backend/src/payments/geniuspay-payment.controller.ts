import { BadRequestException, Body, Controller, Headers, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RequestContext } from '../common/types/request-context';
import { GeniusPayPaymentDto } from './geniuspay-payment.dto';
import { GeniusPayService } from './geniuspay.service';

@ApiTags('payments')
@ApiBearerAuth()
@Controller('payments/geniuspay')
export class GeniusPayPaymentController {
  constructor(private readonly geniusPay: GeniusPayService) {}

  @Post()
  create(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: GeniusPayPaymentDto,
  ) {
    const userId = request.user?.id;
    if (!userId) throw new BadRequestException('Authenticated user is required.');
    return this.geniusPay.createPayment(userId, workspaceId, body);
  }
}
