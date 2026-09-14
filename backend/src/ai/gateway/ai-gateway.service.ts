import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { WalletService } from '../wallet/wallet.service';
import { UsageService } from '../usage/usage.service';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';

@Injectable()
export class AiGatewayService {
  constructor(
    private walletService: WalletService,
    private usageService: UsageService,
    private configService: ConfigService,
    private usersService: UsersService,
  ) {}

  /**
   * Estimate the token cost for an AI operation
   * This is a simplified estimation - in production this would be more sophisticated
   */
  estimateTokens(inputData: any, operation: string): number {
    // Rough estimation based on input size
    const inputString = JSON.stringify(inputData);
    const estimatedInputTokens = Math.ceil(inputString.length / 4); // ~4 chars per token

    // Base output estimation varies by operation
    let estimatedOutputTokens = 0;
    switch (operation) {
      case 'chat_completion':
        estimatedOutputTokens = 500; // reasonable default for chat
        break;
      case 'invoice_extraction':
        estimatedOutputTokens = 200;
        break;
      case 'client_analysis':
        estimatedOutputTokens = 300;
        break;
      case 'stock_analysis':
        estimatedOutputTokens = 300;
        break;
      case 'financial_report':
        estimatedOutputTokens = 500;
        break;
      case 'ocr':
        estimatedOutputTokens = 100; // OCR output is usually concise
        break;
      case 'voice_to_action':
        estimatedOutputTokens = 50;
        break;
      default:
        estimatedOutputTokens = 100; // fallback
    }

    return estimatedInputTokens + estimatedOutputTokens;
  }

  /**
   * Execute an AI operation with provider fallback and token management
   */
  async executeAiOperation(
    userId: string,
    operation: string,
    inputData: any,
    providerPreference: 'anthropic' | 'openai' = 'anthropic',
    modelOverride?: string,
  ): Promise<any> {
    // 1. Estimate tokens needed
    const estimatedTokens = this.estimateTokens(inputData, operation);

    // 2. Get user to check if they exist
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new NotFoundException(`User not found: ${userId}`);
    }

    // 3. Check current token balance
    const currentBalance = await this.walletService.getBalance(userId);
    if (currentBalance < estimatedTokens) {
      throw new BadRequestException(
        `Insufficient tokens. Available: ${currentBalance}, Required: ${estimatedTokens}`
      );
    }

    // 4. Reserve tokens (deduct from balance)
    const reservationSuccessful = await this.walletService.useTokens(
      userId,
      estimatedTokens,
      operation,
      'reservation' // temporary provider for reservation
    );

    if (!reservationSuccessful) {
      // This shouldn't happen if we checked balance, but handle just in case
      throw new BadRequestException('Failed to reserve tokens');
    }

    // 5. Try primary provider
    let result = null;
    let usedProvider = providerPreference;
    let usedModel = modelOverride || this.getDefaultModel(providerPreference);
    let error = null;

    try {
      result = await this.callAiProvider(
        userId,
        operation,
        inputData,
        providerPreference,
        usedModel,
        estimatedTokens
      );
      usedProvider = providerPreference;
    } catch (primaryError) {
      error = primaryError;
      // 6. Try fallback provider if primary fails
      const fallbackProvider = providerPreference === 'anthropic' ? 'openai' : 'anthropic';

      // Check if fallback provider is configured
      const fallbackApiKey = this.getApiKey(fallbackProvider);
      if (fallbackApiKey) {
        try {
          usedModel = modelOverride || this.getDefaultModel(fallbackProvider);
          result = await this.callAiProvider(
            userId,
            operation,
            inputData,
            fallbackProvider,
            usedModel,
            estimatedTokens
          );
          usedProvider = fallbackProvider;
          error = null; // clear error since fallback succeeded
        } catch (fallbackError) {
          error = fallbackError;
          // Both providers failed
        }
      } else {
        // No fallback provider configured
      }
    }

    // 7. Handle outcome
    if (result !== null && error === null) {
      // Success: keep the token deduction (reservation is already deducted)
      // Extract actual token usage from result if available
      const actualInputTokens = result.usage?.prompt_tokens || 0;
      const actualOutputTokens = result.usage?.completion_tokens || 0;
      const actualTotalTokens = result.usage?.total_tokens || estimatedTokens;

      // Log successful usage
      await this.usageService.logUsage(
        userId,
        usedProvider,
        usedModel,
        actualInputTokens,
        actualOutputTokens,
        0, // cost in FCFA - would be calculated from actual provider pricing
        operation,
        actualTotalTokens // tokensUsed
      );

      return result;
    } else {
      // Failure: refund the reserved tokens
      await this.walletService.creditTokens(
        userId,
        estimatedTokens,
        'AI_TOKEN_REFUND',
        undefined, // subscriptionId
        undefined, // paymentId
        operation,
        usedProvider || providerPreference,
        0, // providerCostFcfa
        undefined, // reference
        `AI operation failed: ${error && typeof error === 'object' && 'message' in error ? (error as any).message : 'Unknown error'}`
      );

      throw error || new BadRequestException('AI operation failed with no error details');
    }
  }

  /**
   * Call a specific AI provider
   * In a real implementation, this would make actual API calls
   */
  private async callAiProvider(
    userId: string,
    operation: string,
    inputData: any,
    provider: 'anthropic' | 'openai',
    model: string,
    estimatedTokens: number
  ): Promise<any> {
    // Simulate AI provider call
    // In production, this would use the actual Anthropic or OpenAI SDK

    // Simulate processing delay
    await new Promise(resolve => setTimeout(resolve, 100));

    // Simulate occasional failure for demonstration (10% failure rate)
    if (Math.random() < 0.1) {
      throw new Error(`${provider.toUpperCase()} service temporarily unavailable`);
    }

    // Return simulated response based on operation
    switch (operation) {
      case 'chat_completion':
        return {
          id: `chatcmpl-${Date.now()}`,
          object: 'chat.completion',
          created: Date.now(),
          model,
          choices: [{
            index: 0,
            message: {
              role: 'assistant',
              content: `This is a simulated ${provider} response for operation ${operation}.`,
            },
            finish_reason: 'stop',
          }],
          usage: {
            prompt_tokens: Math.floor(estimatedTokens * 0.3),
            completion_tokens: Math.floor(estimatedTokens * 0.7),
            total_tokens: estimatedTokens,
          }
        };

      case 'invoice_extraction':
        return {
          invoiceData: {
            clientName: 'Simulated Client',
            amount: 100000,
            date: new Date().toISOString().split('T')[0],
            items: [{ description: 'Simulated item', quantity: 1, unitPrice: 100000 }]
          },
          confidence: 0.95
        };

      case 'client_analysis':
        return {
          analysis: {
            clientValue: 'high',
            riskLevel: 'low',
            recommendedActions: ['Offer premium services', 'Check for upsell opportunities']
          }
        };

      case 'stock_analysis':
        return {
          analysis: {
            stockLevel: 'adequate',
            recommendedOrder: 50,
            trendingItems: ['Item A', 'Item B']
          }
        };

      case 'financial_report':
        return {
          report: {
            period: 'last_month',
            revenue: 5000000,
            expenses: 3000000,
            profit: 2000000,
            cashFlow: 1500000
          }
        };

      case 'ocr':
        return {
          text: 'SIMULATED OCR TEXT FROM DOCUMENT',
          confidence: 0.92
        };

      case 'voice_to_action':
        return {
          action: 'create_invoice',
          parameters: {
            clientId: 'simulated-client-id',
            amount: 75000
          },
          confidence: 0.88
        };

      default:
        return {
          result: `Simulated ${provider} response for ${operation}`,
          timestamp: Date.now()
        };
    }
  }

  /**
   * Get default model for a provider
   */
  private getDefaultModel(provider: 'anthropic' | 'openai'): string {
    switch (provider) {
      case 'anthropic':
        return this.configService.get<string>('DEFAULT_ANTHROPIC_MODEL') || 'claude-3-5-sonnet-20241022';
      case 'openai':
        return this.configService.get<string>('DEFAULT_OPENAI_MODEL') || 'gpt-4o';
      default:
        return 'claude-3-5-sonnet-20241022';
    }
  }

  /**
   * Get API key for a provider
   */
  private getApiKey(provider: 'anthropic' | 'openai'): string | undefined {
    if (provider === 'anthropic') {
      return this.configService.get<string>('ANTHROPIC_API_KEY');
    } else {
      return this.configService.get<string>('OPENAI_API_KEY');
    }
  }
}