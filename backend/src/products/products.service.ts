import { BadRequestException, Injectable } from '@nestjs/common';
import { AuthenticatedUser, WorkspaceKind } from '../common/types/request-context';
import { SupabaseService } from '../supabase/supabase.service';
import { CreateProductDto } from './product.dto';

export interface ProductSummary {
  id: string;
  kind: string;
  name: string;
  sku: string | null;
  unit: string;
  salePrice: number;
  taxRate: number;
  trackStock: boolean;
}

interface TenantContext {
  id: string;
  kind: WorkspaceKind;
}

@Injectable()
export class ProductsService {
  constructor(private readonly supabase: SupabaseService) {}

  async list(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    search?: string,
  ): Promise<ProductSummary[]> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    let query = this.supabase.admin
      .from('products')
      .select('id, kind, name, sku, unit, sale_price, tax_rate, track_stock')
      .eq(column, tenant.id)
      .eq('is_archived', false)
      .order('name', { ascending: true })
      .limit(100);
    if (search?.trim()) {
      const value = search.trim().replaceAll(',', ' ');
      query = query.or(`name.ilike.%${value}%,sku.ilike.%${value}%`);
    }
    const { data, error } = await query;
    if (error) throw new BadRequestException('Impossible de charger les produits.');
    return (data ?? []).map((product) => this.toSummary(product));
  }

  async create(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    input: CreateProductDto,
  ): Promise<ProductSummary> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    const { data, error } = await this.supabase.admin
      .from('products')
      .insert({
        [column]: tenant.id,
        kind: input.kind,
        name: input.name.trim(),
        sku: input.sku?.trim() || null,
        unit: input.unit?.trim() || 'unité',
        sale_price: input.salePrice ?? 0,
        tax_rate: input.taxRate ?? 0,
        track_stock: input.trackStock ?? false,
        created_by: user.id,
      })
      .select('id, kind, name, sku, unit, sale_price, tax_rate, track_stock')
      .single();
    if (error || !data) throw new BadRequestException('Impossible de créer le produit.');
    return this.toSummary(data);
  }

  private async resolveWorkspace(
    userId: string,
    workspaceId: string | undefined,
  ): Promise<TenantContext> {
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

  private toSummary(product: Record<string, unknown>): ProductSummary {
    return {
      id: product.id as string,
      kind: product.kind as string,
      name: product.name as string,
      sku: (product.sku as string | null) ?? null,
      unit: (product.unit as string) ?? 'unité',
      salePrice: Number(product.sale_price ?? 0),
      taxRate: Number(product.tax_rate ?? 0),
      trackStock: Boolean(product.track_stock),
    };
  }
}
