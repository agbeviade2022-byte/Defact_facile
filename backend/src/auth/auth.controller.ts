import { Body, Controller, Post } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';
import { EmailOtpService } from './email-otp.service';
import { RequestEmailOtpDto, VerifyEmailOtpDto } from './email-otp.dto';
import { GoogleAuthDto } from './google-auth.dto';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(
    private readonly auth: AuthService,
    private readonly emailOtp: EmailOtpService,
  ) {}

  @Public()
  @Post('email/request-code')
  requestEmailCode(@Body() input: RequestEmailOtpDto) {
    return this.emailOtp.requestCode(input.email);
  }

  @Public()
  @Post('email/verify-code')
  verifyEmailCode(@Body() input: VerifyEmailOtpDto) {
    return this.emailOtp.verifyCode(input.email, input.code);
  }

  @Public()
  @Post('google')
  signInWithGoogle(@Body() input: GoogleAuthDto) {
    return this.auth.signInWithGoogle(input.idToken);
  }
}
