import { Body, Controller, Post } from '@nestjs/common';
import { Public } from '../common/decorators/public.decorator';
import { GoogleAuthDto } from './google-auth.dto';
import { AuthService } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Public()
  @Post('google')
  signInWithGoogle(@Body() input: GoogleAuthDto) {
    return this.auth.signInWithGoogle(input.idToken);
  }
}
