export type AiProviderName = 'CLAUDE' | 'OPENAI';

export interface AiCompletionRequest {
  prompt: string;
  model?: string;
  maxTokens?: number;
}

export interface AiCompletionResult {
  provider: AiProviderName;
  model: string;
  text: string;
  inputTokens: number;
  outputTokens: number;
  costXof: number;
}

export interface AiProvider {
  readonly name: AiProviderName;
  complete(request: AiCompletionRequest): Promise<AiCompletionResult>;
}
