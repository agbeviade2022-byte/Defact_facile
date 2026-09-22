import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AuthenticatedUser, WorkspaceKind } from '../common/types/request-context';
import { SupabaseService } from '../supabase/supabase.service';
import { CreateInvoiceFromQuoteDto } from './invoice.dto';

export interface InvoiceSummary {
  id: string;
  number: string;
  status: string;
  customerId: string | null;
  quoteId: string | null;
  issueDate: string;
  dueDate: string | null;
  currency: string;
  subtotal: number;
  taxAmount: number;
  total: number;
  amountPaid: number;
  amountDue: number;
  notes: string | null;
}

interface TenantContext {
  id: string;
  kind: WorkspaceKind;
}

interface QuoteRecord {
  id: string;
  customer_id: string | null;
  converted_invoice_id: string | null;
  currency: string;
  subtotal: number;
  tax_amount: number;
  total: number;
  notes: string | null;
}

interface QuoteItemRecord {
  product_id: string | null;
  position: number;
  description: string;
  quantity: number;
  unit: string | null;
  unit_price: number;
  tax_rate: number;
  line_subtotal: number;
  line_tax: number;
  line_total: number;
}

@Injectable()
export class InvoicesService {
  constructor(private readonly supabase: SupabaseService) {}

  async list(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    search?: string,
  ): Promise<InvoiceSummary[]> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    let query = this.supabase.admin
      .from('invoices')
      .select(
        'id, number, status, customer_id, quote_id, issue_date, due_date, currency, subtotal, tax_amount, total, amount_paid, amount_due, notes',
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
    if (error) throw new BadRequestException('Impossible de charger les factures.');
    return (data ?? []).map((invoice) => this.toSummary(invoice));
  }

  async createFromQuote(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    input: CreateInvoiceFromQuoteDto,
  ): Promise<InvoiceSummary> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    const { data: quote, error: quoteError } = await this.supabase.admin
      .from('quotes')
      .select('id, customer_id, converted_invoice_id, currency, subtotal, tax_amount, total, notes')
      .eq('id', input.quoteId)
      .eq(column, tenant.id)
      .maybeSingle<QuoteRecord>();
    if (quoteError || !quote) throw new BadRequestException('Devis inaccessible.');
    if (quote.converted_invoice_id) {
      throw new BadRequestException('Ce devis possède déjà une facture.');
    }

    const { data: quoteItems, error: itemsError } = await this.supabase.admin
      .from('quote_items')
      .select(
        'product_id, position, description, quantity, unit, unit_price, tax_rate, line_subtotal, line_tax, line_total',
      )
      .eq('quote_id', quote.id)
      .order('position', { ascending: true })
      .returns<QuoteItemRecord[]>();
    if (itemsError || !quoteItems?.length) {
      throw new BadRequestException('Le devis ne contient aucune ligne.');
    }

    const amountDue = this.round(Number(quote.total));
    const number = `FA-${new Date().toISOString().slice(0, 10).replaceAll('-', '')}-${randomUUID().slice(0, 8).toUpperCase()}`;
    const { data: invoice, error: invoiceError } = await this.supabase.admin
      .from('invoices')
      .insert({
        [column]: tenant.id,
        customer_id: quote.customer_id,
        quote_id: quote.id,
        number,
        currency: quote.currency,
        subtotal: quote.subtotal,
        tax_amount: quote.tax_amount,
        total: quote.total,
        amount_due: amountDue,
        notes: input.notes?.trim() || quote.notes,
        created_by: user.id,
      })
      .select(
        'id, number, status, customer_id, quote_id, issue_date, due_date, currency, subtotal, tax_amount, total, amount_paid, amount_due, notes',
      )
      .single();
    if (invoiceError || !invoice) {
      throw new BadRequestException('Impossible de créer la facture.');
    }

    const { error: invoiceItemsError } = await this.supabase.admin.from('invoice_items').insert(
      quoteItems.map((item) => ({
        invoice_id: invoice.id,
        product_id: item.product_id,
        position: item.position,
        description: item.description,
        quantity: item.quantity,
        unit: item.unit,
        unit_price: item.unit_price,
        tax_rate: item.tax_rate,
        line_subtotal: item.line_subtotal,
        line_tax: item.line_tax,
        line_total: item.line_total,
      })),
    );
    if (invoiceItemsError) {
      await this.supabase.admin.from('invoices').update({ status: 'VOID' }).eq('id', invoice.id);
      throw new BadRequestException('Impossible d’enregistrer les lignes de la facture.');
    }

    const { error: quoteUpdateError } = await this.supabase.admin
      .from('quotes')
      .update({ converted_invoice_id: invoice.id })
      .eq('id', quote.id)
      .is('converted_invoice_id', null);
    if (quoteUpdateError) {
      await this.supabase.admin.from('invoices').update({ status: 'VOID' }).eq('id', invoice.id);
      throw new BadRequestException('Impossible de rattacher la facture au devis.');
    }
    return this.toSummary(invoice);
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

  private toSummary(invoice: Record<string, unknown>): InvoiceSummary {
    return {
      id: invoice.id as string,
      number: invoice.number as string,
      status: invoice.status as string,
      customerId: (invoice.customer_id as string | null) ?? null,
      quoteId: (invoice.quote_id as string | null) ?? null,
      issueDate: invoice.issue_date as string,
      dueDate: (invoice.due_date as string | null) ?? null,
      currency: (invoice.currency as string) ?? 'XOF',
      subtotal: Number(invoice.subtotal ?? 0),
      taxAmount: Number(invoice.tax_amount ?? 0),
      total: Number(invoice.total ?? 0),
      amountPaid: Number(invoice.amount_paid ?? 0),
      amountDue: Number(invoice.amount_due ?? 0),
      notes: (invoice.notes as string | null) ?? null,
    };
  }

  private round(value: number): number {
    return Math.round(value * 100) / 100;
  }
}
