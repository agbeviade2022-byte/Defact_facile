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
import { CreateProductDto, ProductQueryDto } from './product.dto';
import { ProductSummary, ProductsService } from './products.service';

@ApiTags('products')
@ApiBearerAuth()
@Controller('products')
export class ProductsController {
  constructor(private readonly products: ProductsService) {}

  @Get()
  list(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Query() query: ProductQueryDto,
  ): Promise<ProductSummary[]> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.products.list(request.user, workspaceId, query.search);
  }

  @Post()
  create(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: CreateProductDto,
  ): Promise<ProductSummary> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.products.create(request.user, workspaceId, body);
  }
}
