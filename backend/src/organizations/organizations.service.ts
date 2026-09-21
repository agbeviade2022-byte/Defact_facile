import { BadRequestException, ForbiddenException, Injectable } from '@nestjs/common';
import { AuthenticatedUser } from '../common/types/request-context';
import { SupabaseService } from '../supabase/supabase.service';

export interface OrganizationMemberSummary {
  id: string;
  userId: string;
  email: string | null;
  fullName: string | null;
  roleId: string;
  roleCode: string;
  roleName: string;
  status: string;
  joinedAt: string | null;
}

interface MembershipAccess {
  id: string;
  roleCode: string;
}

@Injectable()
export class OrganizationService {
  constructor(private readonly supabase: SupabaseService) {}

  async listMembers(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
  ): Promise<OrganizationMemberSummary[]> {
    await this.requireAdmin(user.id, workspaceId);
    const { data, error } = await this.supabase.admin
      .from('organization_members')
      .select(
        'id, user_id, role_id, status, joined_at, role:roles(code, name), user:users(email, full_name)',
      )
      .eq('organization_id', workspaceId)
      .order('created_at', { ascending: true });
    if (error) throw new BadRequestException('Impossible de charger les membres.');
    return (data ?? []).map((row) => this.toSummary(row));
  }

  async updateMemberRole(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    memberId: string,
    roleId: string,
  ): Promise<OrganizationMemberSummary> {
    await this.requireAdmin(user.id, workspaceId);
    const { data: role, error: roleError } = await this.supabase.admin
      .from('roles')
      .select('id, code, name, organization_id, is_system')
      .eq('id', roleId)
      .maybeSingle();
    if (roleError || !role || (role.is_system !== true && role.organization_id !== workspaceId)) {
      throw new BadRequestException('Rôle inaccessible pour cette organisation.');
    }
    const { data, error } = await this.supabase.admin
      .from('organization_members')
      .update({ role_id: roleId })
      .eq('id', memberId)
      .eq('organization_id', workspaceId)
      .select(
        'id, user_id, role_id, status, joined_at, role:roles(code, name), user:users(email, full_name)',
      )
      .single();
    if (error || !data) throw new BadRequestException('Impossible de modifier le rôle.');
    return this.toSummary(data);
  }

  private async requireAdmin(
    userId: string,
    workspaceId: string | undefined,
  ): Promise<MembershipAccess> {
    if (!workspaceId) throw new BadRequestException('X-Workspace-Id est requis.');
    const { data, error } = await this.supabase.admin
      .from('organization_members')
      .select('id, role:roles(code)')
      .eq('organization_id', workspaceId)
      .eq('user_id', userId)
      .eq('status', 'ACTIVE')
      .maybeSingle();
    if (error || !data) throw new ForbiddenException('Accès organisationnel requis.');
    const role = Array.isArray(data.role) ? data.role[0] : data.role;
    if (!role) throw new ForbiddenException('Rôle organisationnel introuvable.');
    const roleCode = role.code as string;
    if (!['OWNER', 'ADMIN'].includes(roleCode)) {
      throw new ForbiddenException('Seuls les administrateurs peuvent gérer l’équipe.');
    }
    return { id: data.id as string, roleCode };
  }

  private toSummary(row: Record<string, unknown>): OrganizationMemberSummary {
    const role = Array.isArray(row.role) ? row.role[0] : row.role;
    const user = Array.isArray(row.user) ? row.user[0] : row.user;
    if (!role || !user) throw new BadRequestException('Données membre incomplètes.');
    return {
      id: row.id as string,
      userId: row.user_id as string,
      email: (user.email as string | null) ?? null,
      fullName: (user.full_name as string | null) ?? null,
      roleId: row.role_id as string,
      roleCode: role.code as string,
      roleName: role.name as string,
      status: row.status as string,
      joinedAt: (row.joined_at as string | null) ?? null,
    };
  }
}
