import { BadRequestException, Injectable } from '@nestjs/common';
import { SupabaseService } from '../supabase/supabase.service';
import { AuthenticatedUser, WorkspaceKind } from '../common/types/request-context';
import { CreateCustomerDto } from './customer.dto';

export interface CustomerSummary {
  id: string;
  type: 'INDIVIDUAL' | 'COMPANY';
  name: string;
  email: string | null;
  phone: string | null;
  address: string | null;
  city: string | null;
  notes: string | null;
  createdAt: string;
}

@Injectable()
export class CustomersService {
  constructor(private readonly supabase: SupabaseService) {}

  async list(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    search?: string,
  ): Promise<CustomerSummary[]> {
    const workspace = await this.resolveWorkspace(user.id, workspaceId);
    const column = workspace.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    let query = this.supabase.admin
      .from('customers')
      .select('id, type, name, email, phone, address, city, notes, created_at')
      .eq(column, workspace.id)
      .eq('is_archived', false)
      .order('name', { ascending: true })
      .limit(100);
    if (search?.trim()) {
      const value = search.trim().replaceAll(',', ' ');
      query = query.or(`name.ilike.%${value}%,phone.ilike.%${value}%,email.ilike.%${value}%`);
    }
    const { data, error } = await query;
    if (error) throw new BadRequestException('Impossible de charger les clients.');
    return (data ?? []).map((customer) => this.toSummary(customer));
  }

  async create(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    input: CreateCustomerDto,
  ): Promise<CustomerSummary> {
    const workspace = await this.resolveWorkspace(user.id, workspaceId);
    const column = workspace.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    const { data, error } = await this.supabase.admin
      .from('customers')
      .insert({
        [column]: workspace.id,
        type: input.type,
        name: input.name.trim(),
        email: input.email?.trim() || null,
        phone: input.phone?.trim() || null,
        address: input.address?.trim() || null,
        city: input.city?.trim() || null,
        notes: input.notes?.trim() || null,
        created_by: user.id,
      })
      .select('id, type, name, email, phone, address, city, notes, created_at')
      .single();
    if (error || !data) throw new BadRequestException('Impossible de créer le client.');
    return this.toSummary(data);
  }

  private async resolveWorkspace(
    userId: string,
    workspaceId: string | undefined,
  ): Promise<{ id: string; kind: WorkspaceKind }> {
    if (!workspaceId) throw new BadRequestException('X-Workspace-Id est requis.');
    const personal = await this.supabase.admin
      .from('personal_workspaces')
      .select('id')
      .eq('id', workspaceId)
      .eq('user_id', userId)
      .maybeSingle();
    if (personal.data) return { id: workspaceId, kind: 'personal' };
    const organization = await this.supabase.admin
      .from('organization_members')
      .select('id')
      .eq('organization_id', workspaceId)
      .eq('user_id', userId)
      .eq('status', 'ACTIVE')
      .maybeSingle();
    if (organization.data) return { id: workspaceId, kind: 'organization' };
    throw new BadRequestException('Workspace inaccessible.');
  }

  private toSummary(customer: Record<string, unknown>): CustomerSummary {
    return {
      id: customer.id as string,
      type: customer.type as 'INDIVIDUAL' | 'COMPANY',
      name: customer.name as string,
      email: (customer.email as string | null) ?? null,
      phone: (customer.phone as string | null) ?? null,
      address: (customer.address as string | null) ?? null,
      city: (customer.city as string | null) ?? null,
      notes: (customer.notes as string | null) ?? null,
      createdAt: customer.created_at as string,
    };
  }
}
