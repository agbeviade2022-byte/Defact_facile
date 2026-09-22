import { BadRequestException, Body, Controller, Get, Headers, Post, Req } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RequestContext } from '../common/types/request-context';
import { StockMovementDto } from './inventory.dto';
import { InventoryService, StockSummary } from './inventory.service';

@ApiTags('inventory')
@ApiBearerAuth()
@Controller('inventory')
export class InventoryController {
  constructor(private readonly inventory: InventoryService) {}

  @Get()
  list(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
  ): Promise<StockSummary[]> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.inventory.list(request.user, workspaceId);
  }

  @Post('movements')
  createMovement(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Body() body: StockMovementDto,
  ): Promise<StockSummary> {
    if (!request.user) throw new BadRequestException('Identité utilisateur indisponible.');
    return this.inventory.createMovement(request.user, workspaceId, body);
  }
}
