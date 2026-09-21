import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Patch,
  Req,
  UnauthorizedException,
} from '@nestjs/common';
import { RequestContext } from '../common/types/request-context';
import { UpdateMemberRoleDto } from './organization.dto';
import { OrganizationService, OrganizationMemberSummary } from './organizations.service';

@Controller('organizations')
export class OrganizationsController {
  constructor(private readonly organizations: OrganizationService) {}

  @Get('members')
  listMembers(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
  ): Promise<OrganizationMemberSummary[]> {
    return this.organizations.listMembers(this.requireUser(request), workspaceId);
  }

  @Patch('members/:memberId/role')
  updateMemberRole(
    @Req() request: RequestContext,
    @Headers('x-workspace-id') workspaceId: string | undefined,
    @Param('memberId') memberId: string,
    @Body() body: UpdateMemberRoleDto,
  ): Promise<OrganizationMemberSummary> {
    if (!memberId) throw new BadRequestException('Membre invalide.');
    return this.organizations.updateMemberRole(
      this.requireUser(request),
      workspaceId,
      memberId,
      body.roleId,
    );
  }

  private requireUser(request: RequestContext) {
    if (!request.user) throw new UnauthorizedException('Authentification requise.');
    return request.user;
  }
}
