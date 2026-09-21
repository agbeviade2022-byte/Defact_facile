import { BadRequestException, Injectable } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AuthenticatedUser, WorkspaceKind } from '../common/types/request-context';
import { SupabaseService } from '../supabase/supabase.service';
import { CreateInvoicePaymentDto } from './payment.dto';

export interface PaymentSummary {
  id: string;
  invoiceId: string | null;
  amount: number;
  currency: string;
  method: string;
  paidAt: string;
  reference: string | null;
  notes: string | null;
  status: string;
}

interface TenantContext {
  id: string;
  kind: WorkspaceKind;
}

@Injectable()
export class PaymentsService {
  constructor(private readonly supabase: SupabaseService) {}

  async list(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    invoiceId?: string,
  ): Promise<PaymentSummary[]> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    let query = this.supabase.admin
      .from('payments')
      .select('id, invoice_id, amount, currency, method, paid_at, reference, notes, status')
      .eq(column, tenant.id)
      .order('paid_at', { ascending: false })
      .limit(100);
    if (invoiceId) query = query.eq('invoice_id', invoiceId);
    const { data, error } = await query;
    if (error) throw new BadRequestException('Impossible de charger les paiements.');
    return (data ?? []).map((payment) => this.toSummary(payment));
  }

  async create(
    user: AuthenticatedUser,
    workspaceId: string | undefined,
    input: CreateInvoicePaymentDto,
  ): Promise<PaymentSummary> {
    const tenant = await this.resolveWorkspace(user.id, workspaceId);
    const column = tenant.kind === 'personal' ? 'personal_workspace_id' : 'organization_id';
    const { data: invoice, error: invoiceError } = await this.supabase.admin
      .from('invoices')
      .select('id, customer_id, currency, total, amount_paid, amount_due, status')
      .eq('id', input.invoiceId)
      .eq(column, tenant.id)
      .maybeSingle();
    if (invoiceError || !invoice) throw new BadRequestException('Facture inaccessible.');
    if (['CANCELLED', 'VOID', 'ARCHIVED', 'PAID'].includes(invoice.status as string)) {
      throw new BadRequestException('Cette facture ne peut plus recevoir de paiement.');
    }
    const amount = this.round(input.amount);
    const amountDue = this.round(Number(invoice.amount_due));
    if (amount > amountDue) {
      throw new BadRequestException('Le paiement dépasse le montant restant.');
    }

    const { data: payment, error: paymentError } = await this.supabase.admin
      .from('payments')
      .insert({
        [column]: tenant.id,
        invoice_id: invoice.id,
        customer_id: invoice.customer_id,
        method: input.method,
        amount,
        currency: invoice.currency,
        reference: input.reference?.trim() || `PAY-${randomUUID().slice(0, 8).toUpperCase()}`,
        notes: input.notes?.trim() || null,
        created_by: user.id,
      })
      .select('id, invoice_id, amount, currency, method, paid_at, reference, notes, status')
      .single();
    if (paymentError || !payment) {
      throw new BadRequestException('Impossible d’enregistrer le paiement.');
    }

    const newAmountPaid = this.round(Number(invoice.amount_paid) + amount);
    const newAmountDue = this.round(Math.max(0, Number(invoice.total) - newAmountPaid));
    const newStatus = newAmountDue === 0 ? 'PAID' : 'PARTIALLY_PAID';
    const { error: invoiceUpdateError } = await this.supabase.admin
      .from('invoices')
      .update({
        amount_paid: newAmountPaid,
        amount_due: newAmountDue,
        status: newStatus,
        paid_at: newAmountDue === 0 ? new Date().toISOString() : null,
      })
      .eq('id', invoice.id)
      .eq(column, tenant.id);
    if (invoiceUpdateError) {
      throw new BadRequestException('Paiement enregistré mais facture non actualisée.');
    }
    return this.toSummary(payment);
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

  private toSummary(payment: Record<string, unknown>): PaymentSummary {
    return {
      id: payment.id as string,
      invoiceId: (payment.invoice_id as string | null) ?? null,
      amount: Number(payment.amount ?? 0),
      currency: (payment.currency as string) ?? 'XOF',
      method: payment.method as string,
      paidAt: payment.paid_at as string,
      reference: (payment.reference as string | null) ?? null,
      notes: (payment.notes as string | null) ?? null,
      status: payment.status as string,
    };
  }

  private round(value: number): number {
    return Math.round(value * 100) / 100;
  }
}
