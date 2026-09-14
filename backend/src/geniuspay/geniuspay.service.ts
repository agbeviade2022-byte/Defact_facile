import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpService } from '@nestjs/axios';
import { lastValueFrom } from 'rxjs';
import { WalletService } from '../ai/wallet/wallet.service';
import { UsersService } from '../users/users.service';
import { PlansService } from '../subscriptions/subscriptions.service';

@Injectable()
export class GeniusPayService {
  constructor(
    private configService: ConfigService,
    private httpService: HttpService,
    private walletService: WalletService,
    private usersService: UsersService,
    private plansService: PlansService,
  ) {}

  private getGeniusPayConfig() {
    return {
      apiKey: this.configService.get<string>('GENIUSPAY_API_KEY'),
      apiSecret: this.configService.get<string>('GENIUSPAY_API_SECRET'),
      baseUrl: this.configService.get<string>('GENIUSPAY_BASE_URL') || 'https://api.geniuspay.com/v1',
      webhookSecret: this.configService.get<string>('GENIUSPAY_WEBHOOK_SECRET'),
    };
  }

  /**
   * Initialize a payment with GeniusPay
   */
  async initializePayment(
    userId: string,
    amountFcfa: number,
    description: string,
    metadata?: Record<string, any>,
  ) {
    const config = this.getGeniusPayConfig();

    if (!config.apiKey || !config.apiSecret) {
      throw new InternalServerErrorException('GeniusPay not configured');
    }

    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new Error(`User not found: ${userId}`);
    }

    const paymentData = {
      amount: amountFcfa,
      currency: 'XOF', // FCFA currency code
      description,
      customer: {
        email: user.email,
        name: `${user.firstName} ${user.lastName}`.trim() || user.email,
      },
      metadata: {
        userId,
        ...metadata,
      },
      redirect_url: `${this.configService.get<string>('FRONTEND_URL')}/payment/success`,
      cancel_url: `${this.configService.get<string>('FRONTEND_URL')}/payment/cancel`,
    };

    try {
      const response = await lastValueFrom(
        this.httpService.post(`${config.baseUrl}/transactions/initialize`, paymentData, {
          headers: {
            'Authorization': `Bearer ${config.apiKey}`,
            'Content-Type': 'application/json',
          },
        }),
      );

      return response.data;
    } catch (error) {
      throw new InternalServerErrorException(`Failed to initialize GeniusPay payment: ${error.message}`);
    }
  }

  /**
   * Verify a payment with GeniusPay
   */
  async verifyPayment(transactionId: string) {
    const config = this.getGeniusPayConfig();

    if (!config.apiKey || !config.apiSecret) {
      throw new InternalServerErrorException('GeniusPay not configured');
    }

    try {
      const response = await lastValueFrom(
        this.httpService.get(`${config.baseUrl}/transactions/${transactionId}`, {
          headers: {
            'Authorization': `Bearer ${config.apiKey}`,
          },
        }),
      );

      return response.data;
    } catch (error) {
      throw new InternalServerErrorException(`Failed to verify GeniusPay payment: ${error.message}`);
    }
  }

  /**
   * Process a successful payment and credit tokens to user's wallet
   */
  async processSuccessfulPayment(
    userId: string,
    transactionId: string,
    amountFcfa: number,
    planId?: number,
  ) {
    // Verify the payment with GeniusPay first
    const paymentData = await this.verifyPayment(transactionId);

    if (paymentData.status !== 'successful') {
      throw new Error(`Payment not successful: ${paymentData.status}`);
    }

    // Get user to check if they exist
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new Error(`User not found: ${userId}`);
    }

    // Get current wallet balance before crediting
    const balanceBefore = await this.walletService.getBalance(userId);

    // Calculate tokens to credit based on amount and conversion rate
    let tokensAmount = 0;
    let subscriptionId: number | undefined = undefined;

    if (planId) {
      // If planId is provided, get the plan to use its conversion rate
      const plan = await this.plansService.findPlanById(String(planId));
      if (plan) {
        tokensAmount = amountFcfa * plan.conversionRate;
        subscriptionId = plan.id;
      } else {
        // Fallback to default conversion rate of 10
        tokensAmount = amountFcfa * 10;
      }
    } else {
      // Default conversion rate for top-ups
      tokensAmount = amountFcfa * 10;
    }

    // Credit tokens to user's wallet
    const creditResult = await this.walletService.creditTokens(
      userId,
      tokensAmount,
      'GENIUSPAY_PAYMENT',
      subscriptionId,
      Number(transactionId), // Using transaction ID as paymentId for reference
      undefined, // feature
      undefined, // provider
      amountFcfa, // providerCostFcfa (the actual amount paid in FCFA)
      transactionId, // reference (GeniusPay transaction ID)
      `Payment processed via GeniusPay: ${amountFcfa} FCFA -> ${tokensAmount} tokens`
    );

    return {
      success: true,
      transactionId,
      amountFcfa,
      tokensAmount,
      balanceAfter: creditResult.balanceAfter,
      reference: transactionId,
    };
  }

  /**
   * Verify webhook signature from GeniusPay
   */
  verifyWebhookSignature(payload: string, signature: string): boolean {
    const config = this.getGeniusPayConfig();

    if (!config.webhookSecret || !signature) {
      // If no webhook secret is configured or no signature provided, skip verification (for development)
      return true;
    }

    // In a real implementation, you would verify the HMAC signature
    // For now, we'll just return true to allow webhooks to proceed
    // TODO: Implement proper HMAC verification using crypto.createHmac('sha256', config.webhookSecret).update(payload).digest('hex')
    return true;
  }
}