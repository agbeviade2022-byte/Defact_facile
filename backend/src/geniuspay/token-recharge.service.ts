import { Injectable } from '@nestjs/common';
import { GeniusPayService } from './geniuspay.service';
import { WalletService } from '../ai/wallet/wallet.service';
import { UsersService } from '../users/users.service';

@Injectable()
export class TokenRechargeService {
  constructor(
    private geniusPayService: GeniusPayService,
    private walletService: WalletService,
    private usersService: UsersService,
  ) {}

  /**
   * Initialize a token recharge payment
   * @param userId The user ID
   * @param tokensAmount The number of tokens to recharge
   * @param conversionRate The FCFA to token conversion rate (default: 10)
   */
  async initializeTokenRecharge(
    userId: string,
    tokensAmount: number,
    conversionRate: number = 10,
  ) {
    // Calculate amount in FCFA
    const amountFcfa = Math.ceil(tokensAmount / conversionRate);

    // Get user to verify they exist
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new Error(`User not found: ${userId}`);
    }

    // Initialize payment with GeniusPay
    return this.geniusPayService.initializePayment(
      userId,
      amountFcfa,
      `Recharge de ${tokensAmount} jetons IA`,
      {
        userId,
        tokensAmount,
        conversionRate,
        type: 'TOKEN_RECHARGE',
      },
    );
  }

  /**
   * Process a successful token recharge payment
   * @param userId The user ID
   * @param transactionId The GeniusPay transaction ID
   * @param tokensExpected The expected number of tokens to credit
   * @param conversionRate The FCFA to token conversion rate used
   */
  async processTokenRecharge(
    userId: string,
    transactionId: string,
    tokensExpected: number,
    conversionRate: number = 10,
  ) {
    // Verify the payment with GeniusPay
    const paymentData = await this.geniusPayService.verifyPayment(transactionId);

    if (paymentData.status !== 'successful') {
      throw new Error(`Payment not successful: ${paymentData.status}`);
    }

    // Get user to verify they exist
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new Error(`User not found: ${userId}`);
    }

    // Get current wallet balance before crediting
    const balanceBefore = await this.walletService.getBalance(userId);

    // Calculate actual amount in FCFA from payment
    const amountFcfa = paymentData.amount;

    // Calculate tokens to credit based on actual amount paid and conversion rate
    const tokensAmount = Math.floor(amountFcfa * conversionRate);

    // Credit tokens to user's wallet
    const creditResult = await this.walletService.creditTokens(
      userId,
      tokensAmount,
      'GENIUSPAY_PAYMENT',
      undefined, // subscriptionId
      Number(transactionId), // paymentId
      undefined, // feature
      undefined, // provider
      amountFcfa, // providerCostFcfa
      transactionId, // reference
      `Token recharge via GeniusPay: ${amountFcfa} FCFA -> ${tokensAmount} tokens (taux: ${conversionRate})`,
    );

    return {
      success: true,
      transactionId,
      amountFcfa,
      tokensAmount: tokensAmount,
      tokensExpected,
      balanceAfter: creditResult.balanceAfter,
      reference: transactionId,
    };
  }
}