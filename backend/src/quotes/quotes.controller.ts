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
import { CreateQuoteDto } from './quote.dto';
import { QuoteQueryDto } from './quote-query.dto';
import { QuoteSummary, QuotesService } from './quotes.service';

@ApiTags('quotes')
@ApiBearerAuth()
@Controller('quotes')
export class QuotesController {
  constructor(private readonly quotes: QuotesService) {}

  @Get()
  list(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Query() query: QuoteQueryDto,
  ): Promise<QuoteSummary[]> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.quotes.list(request.user, workspaceId, query.search);
  }

  @Post()
  create(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: CreateQuoteDto,
  ): Promise<QuoteSummary> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.quotes.create(request.user, workspaceId, body);
  }
}
