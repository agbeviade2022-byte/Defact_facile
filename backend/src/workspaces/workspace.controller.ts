import { Body, Controller, Get, Patch, Post, Req, UnauthorizedException } from '@nestjs/common';
import { RequestContext } from '../common/types/request-context';
import { CreateWorkspaceDto, SelectWorkspaceDto } from './workspace.dto';
import { WorkspaceService, WorkspaceSummary } from './workspace.service';

@Controller('workspaces')
export class WorkspaceController {
  constructor(private readonly workspaces: WorkspaceService) {}

  @Get()
  list(@Req() request: RequestContext): Promise<WorkspaceSummary[]> {
    return this.workspaces.list(this.requireUser(request));
  }

  @Post()
  create(
    @Req() request: RequestContext,
    @Body() input: CreateWorkspaceDto,
  ): Promise<WorkspaceSummary> {
    return this.workspaces.createOrganization(this.requireUser(request), input);
  }

  @Patch('active')
  select(@Req() request: RequestContext, @Body() input: SelectWorkspaceDto): Promise<void> {
    return this.workspaces.select(this.requireUser(request), input);
  }

  private requireUser(request: RequestContext) {
    if (!request.user) throw new UnauthorizedException('Authentification requise.');
    return request.user;
  }
}
