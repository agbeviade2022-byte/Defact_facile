import { Inject, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AnthropicProvider } from './anthropic.provider';
import { AppConfigService } from '../config/app-config.service';
import { OpenAiProvider } from './openai.provider';
import { AiWalletService } from './ai-wallet.service';
import { AiCompletionRequest, AiCompletionResult, AiProvider, AiProviderName } from './ai-provider';

export interface AiGatewayRequest extends AiCompletionRequest {
  userId: string;
  action: string;
  quotaCost: number;
  idempotencyKey: string;
  preferredProvider?: AiProviderName;
}

@Injectable()
export class AiGatewayService {
  private readonly providers: ReadonlyMap<AiProviderName, AiProvider>;

  constructor(
    private readonly config: AppConfigService,
    private readonly wallet: AiWalletService,
    @Inject(AnthropicProvider) anthropic: AnthropicProvider,
    @Inject(OpenAiProvider) openai: OpenAiProvider,
  ) {
    this.providers = new Map<AiProviderName, AiProvider>([
      [anthropic.name, anthropic],
      [openai.name, openai],
    ]);
  }

  async complete(request: AiGatewayRequest): Promise<AiCompletionResult> {
    const first = request.preferredProvider ?? this.defaultProvider();
    const order: AiProviderName[] = [first, first === 'CLAUDE' ? 'OPENAI' : 'CLAUDE'];
    let lastError: unknown;

    for (const providerName of order) {
      const provider = this.providers.get(providerName);
      if (!provider) continue;
      const reservationId = await this.wallet.reserve(
        request.userId,
        request.quotaCost,
        request.action,
        providerName,
        `${request.idempotencyKey}:${providerName}`,
        new Date(Date.now() + 5 * 60 * 1000),
      );

      try {
        const result = await provider.complete(request);
        const committed = await this.wallet.complete(reservationId);
        if (!committed) {
          await this.wallet.expire(reservationId);
          throw new ServiceUnavailableException('La réservation IA a expiré.');
        }
        await this.wallet.recordUsage(request.userId, reservationId, result);
        return result;
      } catch (error: unknown) {
        lastError = error;
        await this.wallet.recordFailure(request.userId, reservationId, providerName);
        await this.wallet.refund(reservationId);
      }
    }

    throw new ServiceUnavailableException(
      lastError instanceof Error ? lastError.message : 'Aucun fournisseur IA disponible.',
    );
  }

  private defaultProvider(): AiProviderName {
    return this.config.get('AI_DEFAULT_PROVIDER') === 'openai' ? 'OPENAI' : 'CLAUDE';
  }
}
