import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AuthenticatedUser, WorkspaceKind } from '../common/types/request-context';
import { SupabaseService } from '../supabase/supabase.service';
import { StockMovementDto } from './inventory.dto';

export interface StockSummary {
  productId: string;
  productName: string;
  sku: string | null;
  unit: string;
  warehouseId: string;
  warehouseName: string;
  quantity: number;
  reservedQuantity: number;
}

interface TenantContext {
  id: string;
  kind: WorkspaceKind;
}

@Injectable()
export class InventoryService {
  constructor(private readonly supabase: SupabaseService) {}

  async list(user: AuthenticatedUser, workspaceId: string | undefined): Promise<StockSummary[]> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const { data, error } = await this.supabase.admin
      .from('stock_levels')
      .select(
        'product_id, warehouse_id, quantity, reserved_quantity, product:products(name, sku, unit), warehouse:warehouses(name)',
      )
      .order('updated_at', { ascending: false })
      .limit(200);
    if (error) throw new BadRequestException('Impossible de charger le stock.');
    const productIds = (data ?? []).map((row) => row.product_id as string);
    if (productIds.length === 0) return [];
    const { data: products, error: productsError } = await this.supabase.admin
      .from('products')
      .select('id')
      .in('id', productIds)
      .or(`personal_workspace_id.eq.${tenant.id},organization_id.eq.${tenant.id}`);
    if (productsError) throw new BadRequestException('Impossible de vérifier le stock.');
    const allowed = new Set((products ?? []).map((product) => product.id as string));
    return (data ?? [])
      .filter((row) => allowed.has(row.product_id as string))
      .map((row) => this.toSummary(row));
  }

  async createMovement(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    input: StockMovementDto,
  ): Promise<StockSummary> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    const { data: product, error: productError } = await this.supabase.admin
      .from('products')
      .select('id, name, sku, unit, track_stock')
      .eq('id', input.productId)
      .eq(column, tenant.id)
      .maybeSingle();
    if (productError || !product) throw new BadRequestException('Produit inaccessible.');
    if (!product.track_stock)
      throw new BadRequestException('Le suivi de stock est désactivé pour ce produit.');
    const warehouseId = input.warehouseId ?? (await this.ensureDefaultWarehouse(tenant, user.id));
    const { data: warehouse, error: warehouseError } = await this.supabase.admin
      .from('warehouses')
      .select('id, name')
      .eq('id', warehouseId)
      .eq(column, tenant.id)
      .maybeSingle();
    if (warehouseError || !warehouse) throw new BadRequestException('Entrepôt inaccessible.');
    const quantity = input.type === 'ADJUSTMENT' ? input.quantity : Math.abs(input.quantity);
    const { error: movementError } = await this.supabase.admin.from('stock_movements').insert({
      [column]: tenant.id,
      product_id: product.id,
      warehouse_id: warehouse.id,
      type: input.type,
      quantity,
      unit_cost: input.unitCost ?? null,
      reason: input.reason?.trim() || null,
      client_event_id: randomUUID(),
      created_by: user.id,
    });
    if (movementError)
      throw new BadRequestException('Impossible d’enregistrer le mouvement de stock.');
    const { data: level, error: levelError } = await this.supabase.admin
      .from('stock_levels')
      .select('product_id, warehouse_id, quantity, reserved_quantity')
      .eq('product_id', product.id)
      .eq('warehouse_id', warehouse.id)
      .single();
    if (levelError || !level) throw new BadRequestException('Impossible de relire le stock.');
    return this.toSummary({ ...level, product, warehouse });
  }

  private async ensureDefaultWarehouse(tenant: TenantContext, userId: string): Promise<string> {
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    const existing = await this.supabase.admin
      .from('warehouses')
      .select('id')
      .eq(column, tenant.id)
      .eq('is_default', true)
      .maybeSingle();
    if (existing.data) return existing.data.id as string;
    const { data, error } = await this.supabase.admin
      .from('warehouses')
      .insert({
        [column]: tenant.id,
        name: 'Entrepôt principal',
        code: 'PRINCIPAL',
        is_default: true,
        created_by: userId,
      })
      .select('id')
      .single();
    if (error || !data) throw new BadRequestException('Impossible de créer l’entrepôt principal.');
    return data.id as string;
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

  private toSummary(row: Record<string, unknown>): StockSummary {
    const product = row.product as Record<string, unknown>;
    const warehouse = row.warehouse as Record<string, unknown>;
    return {
      productId: row.product_id as string,
      productName: product.name as string,
      sku: (product.sku as string | null) ?? null,
      unit: (product.unit as string) ?? 'unité',
      warehouseId: row.warehouse_id as string,
      warehouseName: warehouse.name as string,
      quantity: Number(row.quantity ?? 0),
      reservedQuantity: Number(row.reserved_quantity ?? 0),
    };
  }
}
