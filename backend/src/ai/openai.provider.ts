import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AppConfigService } from '../config/app-config.service';
import { AiCompletionRequest, AiCompletionResult, AiProvider } from './ai-provider';

interface OpenAiResponse {
  model?: string;
  choices?: Array<{ message?: { content?: string } }>;
  usage?: { prompt_tokens?: number; completion_tokens?: number };
}

@Injectable()
export class OpenAiProvider implements AiProvider {
  readonly name = 'OPENAI' as const;

  constructor(private readonly config: AppConfigService) {}

  async complete(request: AiCompletionRequest): Promise<AiCompletionResult> {
    const apiKey = this.config.get('OPENAI_API_KEY');
    if (!apiKey) throw new ServiceUnavailableException('OpenAI est indisponible.');

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'content-type': 'application/json', authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: request.model ?? 'gpt-4o-mini',
        max_tokens: request.maxTokens ?? 1024,
        messages: [{ role: 'user', content: request.prompt }],
      }),
    });
    if (!response.ok) throw new ServiceUnavailableException('OpenAI a échoué.');

    const body = (await response.json()) as OpenAiResponse;
    const inputTokens = body.usage?.prompt_tokens ?? 0;
    const outputTokens = body.usage?.completion_tokens ?? 0;
    return {
      provider: this.name,
      model: body.model ?? request.model ?? 'gpt-4o-mini',
      text: body.choices?.[0]?.message?.content ?? '',
      inputTokens,
      outputTokens,
      costXof: 0,
    };
  }
}
