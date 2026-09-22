import { IsEmail, IsString, Length, MaxLength } from 'class-validator';

export class RequestEmailOtpDto {
  @IsEmail()
  @MaxLength(254)
  email!: string;
}

export class VerifyEmailOtpDto {
  @IsEmail()
  @MaxLength(254)
  email!: string;

  @IsString()
  @Length(6, 6)
  code!: string;
}
