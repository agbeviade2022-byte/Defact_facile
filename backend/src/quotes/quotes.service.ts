import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { SupabaseService } from '../supabase/supabase.service';
import { AuthenticatedUser, WorkspaceKind } from '../common/types/request-context';
import { CreateQuoteDto } from './quote.dto';

export interface QuoteSummary {
  id: string;
  number: string;
  status: string;
  customerId: string | null;
  issueDate: string;
  validUntil: string | null;
  currency: string;
  subtotal: number;
  taxAmount: number;
  total: number;
  notes: string | null;
}

interface TenantContext {
  id: string;
  kind: WorkspaceKind;
}

@Injectable()
export class QuotesService {
  constructor(private readonly supabase: SupabaseService) {}

  async list(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    search?: string,
  ): Promise<QuoteSummary[]> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    let query = this.supabase.admin
      .from('quotes')
      .select(
        'id, number, status, customer_id, issue_date, valid_until, currency, subtotal, tax_amount, total, notes',
      )
      .eq(column, tenant.id)
      .order('issue_date', { ascending: false })
      .order('created_at', { ascending: false })
      .limit(100);
    if (search?.trim()) {
      const value = search.trim().replaceAll(',', ' ').replaceAll('(', ' ').replaceAll(')', ' ');
      query = query.or(`number.ilike.%${value}%,status.ilike.%${value}%`);
    }
    const { data, error } = await query;
    if (error) throw new BadRequestException('Impossible de charger les devis.');
    return (data ?? []).map((quote) => this.toSummary(quote));
  }

  async create(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    input: CreateQuoteDto,
  ): Promise<QuoteSummary> {
    if (input.items.length === 0) {
      throw new BadRequestException('Le devis doit contenir au moins une ligne.');
    }
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    if (input.customerId) await this.assertCustomerAccess(input.customerId, tenant);

    const items = input.items.map((item, position) => {
      const lineSubtotal = this.round(item.quantity * item.unitPrice);
      const lineTax = this.round(lineSubtotal * ((item.taxRate ?? 0) / 100));
      return {
        position,
        description: item.description.trim(),
        quantity: item.quantity,
        unit: item.unit?.trim() || null,
        unit_price: item.unitPrice,
        tax_rate: item.taxRate ?? 0,
        line_subtotal: lineSubtotal,
        line_tax: lineTax,
        line_total: this.round(lineSubtotal + lineTax),
      };
    });
    const subtotal = this.round(items.reduce((sum, item) => sum + item.line_subtotal, 0));
    const taxAmount = this.round(items.reduce((sum, item) => sum + item.line_tax, 0));
    const number = `DV-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}-${randomUUID().slice(0, 8).toUpperCase()}`;
    const { data: quote, error: quoteError } = await this.supabase.admin
      .from('quotes')
      .insert({
        [column]: tenant.id,
        customer_id: input.customerId ?? null,
        number,
        subtotal,
        tax_amount: taxAmount,
        total: this.round(subtotal + taxAmount),
        notes: input.notes?.trim() || null,
        created_by: user.id,
      })
      .select(
        'id, number, status, customer_id, issue_date, valid_until, currency, subtotal, tax_amount, total, notes',
      )
      .single();
    if (quoteError || !quote) throw new BadRequestException('Impossible de créer le devis.');

    const { error: itemsError } = await this.supabase.admin
      .from('quote_items')
      .insert(items.map((item) => ({ ...item, quote_id: quote.id })));
    if (itemsError) {
      await this.supabase.admin.from('quotes').update({ status: 'CANCELLED' }).eq('id', quote.id);
      throw new BadRequestException('Impossible d’enregistrer les lignes du devis.');
    }
    return this.toSummary(quote);
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

  private async assertCustomerAccess(customerId: string, tenant: TenantContext): Promise<void> {
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    const { data, error } = await this.supabase.admin
      .from('customers')
      .select('id')
      .eq('id', customerId)
      .eq(column, tenant.id)
      .maybeSingle();
    if (error || !data) throw new BadRequestException('Client inaccessible.');
  }

  private toSummary(quote: Record<string, unknown>): QuoteSummary {
    return {
      id: quote.id as string,
      number: quote.number as string,
      status: quote.status as string,
      customerId: (quote.customer_id as string | null) ?? null,
      issueDate: quote.issue_date as string,
      validUntil: (quote.valid_until as string | null) ?? null,
      currency: (quote.currency as string) ?? 'XOF',
      subtotal: Number(quote.subtotal ?? 0),
      taxAmount: Number(quote.tax_amount ?? 0),
      total: Number(quote.total ?? 0),
      notes: (quote.notes as string | null) ?? null,
    };
  }

  private round(value: number): number {
    return Math.round(value * 100) / 100;
  }
}
