import { Module } from '@nestjs/common';
import { SupabaseModule } from '../supabase/supabase.module';
import { AuthController } from './auth.controller';
import { AppTokenService } from './app-token.service';
import { AuthService } from './auth.service';
import { GoogleTokenService } from './google-token.service';
import { SupabaseAuthGuard } from './supabase-auth.guard';

@Module({
  imports: [SupabaseModule],
  controllers: [AuthController],
  providers: [AppTokenService, AuthService, GoogleTokenService, SupabaseAuthGuard],
  exports: [AppTokenService, SupabaseAuthGuard],
})
export class AuthModule {}
