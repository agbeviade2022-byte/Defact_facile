import { Controller, Post, Body, Headers, HttpCode, HttpStatus, Get, Param, UseGuards } from '@nestjs/common';
import { GeniusPayService } from './geniuspay.service';
import { TokenRechargeService } from './token-recharge.service';
import { UsersService } from '../users/users.service';
import { JwtAuthGuard } from '../../auth/auth.guard';
import { Request } from 'express';

@Controller('geniuspay')
export class GeniusPayController {
  constructor(
    private geniusPayService: GeniusPayService,
    private tokenRechargeService: TokenRechargeService,
    private usersService: UsersService,
  ) {}

  // Webhook endpoint (no auth required as it's called by GeniusPay)
  @Post('webhook')
  @HttpCode(HttpStatus.OK)
  async handleWebhook(
    @Body() payload: any,
    @Headers('geniuspay-signature') signature: string,
    @Req() request: Request,
  ) {
    // Get raw body for signature verification
    const rawBody = JSON.stringify(payload);

    // Verify webhook signature
    if (!this.geniusPayService.verifyWebhookSignature(rawBody, signature)) {
      throw new Error('Invalid webhook signature');
    }

    // Handle different event types
    switch (payload.event) {
      case 'payment.successful':
        await this.handleSuccessfulPayment(payload.data);
        break;
      case 'payment.failed':
        await this.handleFailedPayment(payload.data);
        break;
      default:
        // Ignore other event types
        break;
    }

    return { status: 'ok' };
  }

  private async handleSuccessfulPayment(paymentData: any) {
    const { userId, transactionId, amount, metadata } = paymentData;

    // Process the payment and credit tokens
    await this.geniusPayService.processSuccessfulPayment(
      userId,
      transactionId,
      amount,
      metadata?.planId,
    );
  }

  private async handleFailedPayment(paymentData: any) {
    // Log failed payment for monitoring/debugging
    console.warn(`GeniusPay payment failed:`, paymentData);
    // In a production system, you might want to notify the user or admin
  }

  // Initialize a subscription payment
  @Post('initialize-subscription/:userId/:planId')
  @UseGuards(JwtAuthGuard)
  async initializeSubscriptionPayment(
    @Param('userId') userId: string,
    @Param('planId') planId: string,
  ) {
    // Get the plan to determine the amount
    // In a real implementation, we would fetch the plan from the database
    // For now, we'll use a placeholder amount that would be replaced with actual plan lookup

    // Verify user exists
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new Error(`User not found: ${userId}`);
    }

    // For demonstration, we'll use a fixed amount
    // In reality, this would come from the plan's iaBudgetFcfa field
    const amountFcfa = 1000; // Example: 1000 FCFA

    return this.geniusPayService.initializePayment(
      userId,
      amountFcfa,
      `Paiement d'abonnement`,
      {
        userId,
        planId: Number(planId),
        type: 'SUBSCRIPTION_PAYMENT',
      },
    );
  }

  // Initialize a token recharge
  @Post('initialize-recharge/:userId/:tokensAmount')
  @UseGuards(JwtAuthGuard)
  async initializeTokenRecharge(
    @Param('userId') userId: string,
    @Param('tokensAmount') tokensAmount: number,
  ) {
    // Verify user exists
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new Error(`User not found: ${userId}`);
    }

    return this.tokenRechargeService.initializeTokenRecharge(
      userId,
      tokensAmount,
    );
  }
}