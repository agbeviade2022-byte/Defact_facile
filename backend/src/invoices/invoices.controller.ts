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
import { CreateInvoiceFromQuoteDto, InvoiceQueryDto } from './invoice.dto';
import { InvoiceSummary, InvoicesService } from './invoices.service';

@ApiTags('invoices')
@ApiBearerAuth()
@Controller('invoices')
export class InvoicesController {
  constructor(private readonly invoices: InvoicesService) {}

  @Get()
  list(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Query() query: InvoiceQueryDto,
  ): Promise<InvoiceSummary[]> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.invoices.list(request.user, workspaceId, query.search);
  }

  @Post('from-quote')
  createFromQuote(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: CreateInvoiceFromQuoteDto,
  ): Promise<InvoiceSummary> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.invoices.createFromQuote(request.user, workspaceId, body);
  }
}
