import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { AuthenticatedUser, WorkspaceKind } from '../common/types/request-context';
import { CreateWorkspaceDto, SelectWorkspaceDto } from './workspace.dto';

export interface WorkspaceSummary {
  id: string;
  kind: WorkspaceKind;
  name: string;
  slug: string | null;
  role: string | null;
  permissions: string[];
}

interface MembershipRow {
  organization_id: string;
  role_id: string;
  status: string;
}

interface OrganizationRow {
  id: string;
  name: string;
  slug: string;
  status: string;
}

interface RoleRow {
  id: string;
  code: string;
}

interface RolePermissionRow {
  role_id: string;
  permission_code: string;
}

@Injectable()
export class WorkspaceService {
  constructor(private readonly supabase: SupabaseService) {}

  async list(user: AuthenticatedUser): Promise<WorkspaceSummary[]> {
    const personal = await this.ensurePersonalWorkspace(user);
    const memberships = await this.getMemberships(user.id);
    if (memberships.length === 0) {
      return [this.personalSummary(personal)];
    }

    const organizationIds = memberships.map((membership) => membership.organization_id);
    const roleIds = memberships.map((membership) => membership.role_id);
    const [organizations, roles, rolePermissions] = await Promise.all([
      this.getOrganizations(organizationIds),
      this.getRoles(roleIds),
      this.getRolePermissions(roleIds),
    ]);

    const organizationById = new Map(
      organizations.map((organization) => [organization.id, organization]),
    );
    const roleById = new Map(roles.map((role) => [role.id, role]));
    const permissionsByRole = new Map<string, string[]>();
    for (const permission of rolePermissions) {
      const values = permissionsByRole.get(permission.role_id) ?? [];
      values.push(permission.permission_code);
      permissionsByRole.set(permission.role_id, values);
    }

    return [
      this.personalSummary(personal),
      ...memberships.flatMap((membership) => {
        const organization = organizationById.get(membership.organization_id);
        const role = roleById.get(membership.role_id);
        if (!organization || organization.status !== 'ACTIVE' || !role) return [];
        return [
          {
            id: organization.id,
            kind: 'organization' as const,
            name: organization.name,
            slug: organization.slug,
            role: role.code,
            permissions: permissionsByRole.get(role.id) ?? [],
          },
        ];
      }),
    ];
  }

  async createOrganization(
    user: AuthenticatedUser,
    input: CreateWorkspaceDto,
  ): Promise<WorkspaceSummary> {
    const slug = input.slug ?? this.slugify(input.name);
    const { data: organization, error: organizationError } = await this.supabase.admin
      .from('organizations')
      .insert({ name: input.name.trim(), slug, created_by: user.id })
      .select('id, name, slug, status')
      .single();
    if (organizationError || !organization) {
      if (organizationError?.code === '23505') {
        throw new ConflictException('Ce nom court est déjà utilisé.');
      }
      throw new BadRequestException('Impossible de créer l’entreprise.');
    }

    const { data: role, error: roleError } = await this.supabase.admin
      .from('roles')
      .select('id')
      .eq('code', 'OWNER')
      .is('organization_id', null)
      .single();
    if (roleError || !role) {
      throw new BadRequestException('Le rôle propriétaire est indisponible.');
    }

    const { error: membershipError } = await this.supabase.admin
      .from('organization_members')
      .insert({
        organization_id: organization.id,
        user_id: user.id,
        role_id: role.id,
        status: 'ACTIVE',
        joined_at: new Date().toISOString(),
      });
    if (membershipError) {
      throw new BadRequestException('Impossible de créer l’appartenance propriétaire.');
    }

    const rolePermissions = await this.getRolePermissions([role.id]);
    return {
      id: organization.id,
      kind: 'organization',
      name: organization.name,
      slug: organization.slug,
      role: 'OWNER',
      permissions: rolePermissions.map((permission) => permission.permission_code),
    };
  }

  async select(user: AuthenticatedUser, input: SelectWorkspaceDto): Promise<void> {
    const workspaces = await this.list(user);
    const workspace = workspaces.find(
      (candidate) => candidate.id === input.id && candidate.kind === input.kind,
    );
    if (!workspace) throw new NotFoundException('Espace introuvable.');

    const { error } = await this.supabase.admin
      .from('users')
      .update({
        last_active_workspace_kind: input.kind,
        last_active_workspace_id: input.id,
      })
      .eq('id', user.id);
    if (error) throw new BadRequestException('Impossible d’enregistrer cet espace.');
  }

  private async ensurePersonalWorkspace(user: AuthenticatedUser): Promise<{
    id: string;
    display_name: string;
  }> {
    const { data: existing, error: readError } = await this.supabase.admin
      .from('personal_workspaces')
      .select('id, display_name')
      .eq('user_id', user.id)
      .maybeSingle();
    if (readError) throw new BadRequestException('Impossible de charger votre espace personnel.');
    if (existing) return existing;

    const { data: created, error: createError } = await this.supabase.admin
      .from('personal_workspaces')
      .insert({
        user_id: user.id,
        display_name: 'Mon espace',
        email: user.email,
      })
      .select('id, display_name')
      .single();
    if (createError || !created) {
      const { data: retried } = await this.supabase.admin
        .from('personal_workspaces')
        .select('id, display_name')
        .eq('user_id', user.id)
        .single();
      if (!retried) throw new BadRequestException('Impossible de créer votre espace personnel.');
      return retried;
    }
    return created;
  }

  private personalSummary(personal: { id: string; display_name: string }): WorkspaceSummary {
    return {
      id: personal.id,
      kind: 'personal',
      name: personal.display_name,
      slug: null,
      role: 'OWNER',
      permissions: [],
    };
  }

  private async getMemberships(userId: string): Promise<MembershipRow[]> {
    const { data, error } = await this.supabase.admin
      .from('organization_members')
      .select('organization_id, role_id, status')
      .eq('user_id', userId)
      .eq('status', 'ACTIVE');
    if (error) throw new BadRequestException('Impossible de charger vos appartenances.');
    return (data ?? []) as MembershipRow[];
  }

  private async getOrganizations(ids: string[]): Promise<OrganizationRow[]> {
    const { data, error } = await this.supabase.admin
      .from('organizations')
      .select('id, name, slug, status')
      .in('id', ids);
    if (error) throw new BadRequestException('Impossible de charger les entreprises.');
    return (data ?? []) as OrganizationRow[];
  }

  private async getRoles(ids: string[]): Promise<RoleRow[]> {
    const { data, error } = await this.supabase.admin
      .from('roles')
      .select('id, code')
      .in('id', ids);
    if (error) throw new BadRequestException('Impossible de charger les rôles.');
    return (data ?? []) as RoleRow[];
  }

  private async getRolePermissions(ids: string[]): Promise<RolePermissionRow[]> {
    const { data, error } = await this.supabase.admin
      .from('role_permissions')
      .select('role_id, permission_code')
      .in('role_id', ids);
    if (error) throw new BadRequestException('Impossible de charger les permissions.');
    return (data ?? []) as RolePermissionRow[];
  }

  private slugify(value: string): string {
    const slug = value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
    if (slug.length < 2) throw new BadRequestException('Le nom de l’entreprise est invalide.');
    return slug;
  }
}
