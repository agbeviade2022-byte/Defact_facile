import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Post,
  Query,
  Req,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RequestContext } from '../common/types/request-context';
import { CreateInvoicePaymentDto, PaymentQueryDto } from './payment.dto';
import { PaymentSummary, PaymentsService } from './payments.service';

@ApiTags('payments')
@ApiBearerAuth()
@Controller('payments')
export class PaymentsController {
  constructor(private readonly payments: PaymentsService) {}

  @Get()
  list(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Query() query: PaymentQueryDto,
  ): Promise<PaymentSummary[]> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.payments.list(request.user, workspaceId, query.invoiceId);
  }

  @Post()
  create(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: CreateInvoicePaymentDto,
  ): Promise<PaymentSummary> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.payments.create(request.user, workspaceId, body);
  }
}
