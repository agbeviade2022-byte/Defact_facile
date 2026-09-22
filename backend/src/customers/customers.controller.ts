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
import { CreateCustomerDto } from './customer.dto';
import { CustomerQueryDto } from './customer-query.dto';
import { CustomerSummary, CustomersService } from './customers.service';

@ApiTags('customers')
@ApiBearerAuth()
@Controller('customers')
export class CustomersController {
  constructor(private readonly customers: CustomersService) {}

  @Get()
  list(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Query() query: CustomerQueryDto,
  ): Promise<CustomerSummary[]> {
    const user = request.user;
    if (!user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.customers.list(user, workspaceId, query.search);
  }

  @Post()
  create(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: CreateCustomerDto,
  ): Promise<CustomerSummary> {
    const user = request.user;
    if (!user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.customers.create(user, workspaceId, body);
  }
}
