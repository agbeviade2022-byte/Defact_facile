import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ThrottlerModule } from '@nestjs/throttler';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';

// Import all feature modules
import { AuthModule } from './auth/auth.module';
import { UsersModule } from './users/users.module';
import { OrganizationsModule } from './organizations/organizations.module';
import { MembershipsModule } from './memberships/memberships.module';
import { RolesModule } from './roles/roles.module';
import { PermissionsModule } from './permissions/permissions.module';
import { CustomersModule } from './customers/customers.module';
import { ProductsModule } from './products/products.module';
import { QuotesModule } from './quotes/quotes.module';
import { InvoicesModule } from './invoices/invoices.module';
import { PaymentsModule } from './payments/payments.module';
import { SalesModule } from './sales/sales.module';
import { InventoryModule } from './inventory/inventory.module';
import { ExpensesModule } from './expenses/expenses.module';
import { SuppliersModule } from './suppliers/suppliers.module';
import { PurchasesModule } from './purchases/purchases.module';
import { DeliveriesModule } from './deliveries/deliveries.module';
import { ReportsModule } from './reports/reports.module';
import { StoresModule } from './stores/stores.module';
import { CashRegisterModule } from './cash_register/cash_register.module';
import { AiModule } from './ai/ai.module';
import { WhatsAppModule } from './whatsapp/whatsapp.module';
import { FNEModule } from './fne/fne.module';
import { PDFModule } from './pdf/pdf.module';
import { NotificationsModule } from './notifications/notifications.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { AntiAbuseModule } from './anti_abuse/anti_abuse.module';
import { AuditModule } from './audit/audit.module';
import { GeniusPayModule } from './geniuspay/geniuspay.module';

@Module({
  imports: [
    // Load environment variables
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['.env.development', '.env'],
    }),

    // Database connection (will be configured with Supabase)
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: () => ({
        type: 'postgres',
        host: process.env.DB_HOST,
        port: parseInt(process.env.DB_PORT) || 5432,
        username: process.env.DB_USERNAME,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_DATABASE,
        schema: process.env.DB_SCHEMA || 'public',
        ssl: process.env.DB_SSL === 'true',
        autoLoadEntities: true,
        synchronize: process.env.DB_SYNCHRONIZE === 'true', // Only in development
      }),
    }),

    // Rate limiting
    ThrottlerModule.forRoot([
      {
        ttl: 60,
        limit: 10,
      },
    ]),

    // Feature modules
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
    PaymentsModule,
    SalesModule,
    InventoryModule,
    ExpensesModule,
    SuppliersModule,
    PurchasesModule,
    DeliveriesModule,
    ReportsModule,
    StoresModule,
    CashRegisterModule,
    AiModule,
    WhatsAppModule,
    FNEModule,
    PDFModule,
    NotificationsModule,
    SubscriptionsModule,
    AntiAbuseModule,
    AuditModule,
    GeniusPayModule,
  ],
  controllers: [],
  providers: [],
})
export class AppModule {}