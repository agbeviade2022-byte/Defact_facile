import { Module } from '@nestjs/common';
import { APP_FILTER, APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AppConfigModule } from './config/config.module';
import { AppConfigService } from './config/app-config.service';
import { SupabaseModule } from './supabase/supabase.module';
import { HealthModule } from './health/health.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

import { AuthModule } from './auth/auth.module';
import { SupabaseAuthGuard } from './auth/supabase-auth.guard';
import { UsersModule } from './users/users.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { MembershipsModule } from './memberships/memberships.module';
import { RolesModule } from './roles/roles.module';
import { PermissionsModule } from './permissions/permissions.module';
import { CustomersModule } from './customers/customers.module';
import { ProductsModule } from './products/products.module';
import { QuotesModule } from './quotes/quotes.module';
import { InvoicesModule } from './invoices/invoices.module';
import { SalesModule } from './sales/sales.module';
import { PaymentsModule } from './payments/payments.module';
import { InventoryModule } from './inventory/inventory.module';
import { ExpensesModule } from './expenses/expenses.module';
import { SuppliersModule } from './suppliers/suppliers.module';
import { PurchasesModule } from './purchases/purchases.module';
import { DeliveriesModule } from './deliveries/deliveries.module';
import { ReportsModule } from './reports/reports.module';
import { StoresModule } from './stores/stores.module';
import { CashRegisterModule } from './cash_register/cash_register.module';
import { AiModule } from './ai/ai.module';
import { WhatsappModule } from './whatsapp/whatsapp.module';
import { FneModule } from './fne/fne.module';
import { PdfModule } from './pdf/pdf.module';
import { NotificationsModule } from './notifications/notifications.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { AntiAbuseModule } from './anti_abuse/anti_abuse.module';
import { AuditModule } from './audit/audit.module';

@Module({
  imports: [
    AppConfigModule,
    SupabaseModule,
    ThrottlerModule.forRootAsync({
      inject: [AppConfigService],
      useFactory: (config: AppConfigService) => [
        {
          ttl: config.get('RATE_LIMIT_TTL_SECONDS') * 1000,
          limit: config.get('RATE_LIMIT_MAX'),
        },
      ],
    }),
    HealthModule,

    AuthModule,
    UsersModule,
    OrganizationsModule,
    MembershipsModule,
    RolesModule,
    PermissionsModule,
    CustomersModule,
    ProductsModule,
    QuotesModule,
    InvoicesModule,
    SalesModule,
    PaymentsModule,
    InventoryModule,
    ExpensesModule,
    SuppliersModule,
    PurchasesModule,
    DeliveriesModule,
    ReportsModule,
    StoresModule,
    CashRegisterModule,
    AiModule,
    WhatsappModule,
    FneModule,
    PdfModule,
    NotificationsModule,
    SubscriptionsModule,
    AntiAbuseModule,
    AuditModule,
  ],
  providers: [
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: SupabaseAuthGuard },
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
  ],
})
export class AppModule {}
