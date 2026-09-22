import { Controller, Get } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { PlanService, PlanSummary } from './plan.service';

@ApiTags('plans')
@ApiBearerAuth()
@Controller('plans')
export class PlanController {
  constructor(private readonly plans: PlanService) {}

  @Get()
  list(): Promise<PlanSummary[]> {
    return this.plans.list();
  }
}
