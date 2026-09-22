import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AppConfigService } from '../config/app-config.service';
import { AiCompletionRequest, AiCompletionResult, AiProvider } from './ai-provider';

interface AnthropicResponse {
  content?: Array<{ type?: string; text?: string }>;
  model?: string;
  usage?: { input_tokens?: number; output_tokens?: number };
}

@Injectable()
export class AnthropicProvider implements AiProvider {
  readonly name = 'CLAUDE' as const;

  constructor(private readonly config: AppConfigService) {}

  async complete(request: AiCompletionRequest): Promise<AiCompletionResult> {
    const apiKey = this.config.get('ANTHROPIC_API_KEY');
    if (!apiKey) throw new ServiceUnavailableException('Claude est indisponible.');

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: request.model ?? 'claude-3-5-haiku-latest',
        max_tokens: request.maxTokens ?? 1024,
        messages: [{ role: 'user', content: request.prompt }],
      }),
    });
    if (!response.ok) throw new ServiceUnavailableException('Claude a échoué.');

    const body = (await response.json()) as AnthropicResponse;
    const inputTokens = body.usage?.input_tokens ?? 0;
    const outputTokens = body.usage?.output_tokens ?? 0;
    return {
      provider: this.name,
      model: body.model ?? request.model ?? 'claude-3-5-haiku-latest',
      text: body.content?.find((item) => item.type === 'text')?.text ?? '',
      inputTokens,
      outputTokens,
      costXof: 0,
    };
  }
}
