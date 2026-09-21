import { createHmac } from 'node:crypto';
import { AppConfigService } from '../config/app-config.service';
import { SupabaseService } from '../supabase/supabase.service';
import { GeniusPayWebhookService } from './geniuspay-webhook.service';

describe('GeniusPayWebhookService', () => {
  it('rejects an invalid signature before touching the database', async () => {
    const config = { get: jest.fn().mockReturnValue('whsec_test') } as unknown as AppConfigService;
    const supabase = {} as SupabaseService;
    const service = new GeniusPayWebhookService(config, supabase);

    await expect(
      service.handle(
        JSON.stringify({ event: 'payment.success', data: {} }),
        'invalid',
        String(Math.floor(Date.now() / 1000)),
        'payment.success',
      ),
    ).rejects.toThrow('Signature GeniusPay invalide.');
  });

  it('accepts the documented timestamp plus raw body signature', async () => {
    const secret = 'whsec_test';
    const rawBody = JSON.stringify({
      event: 'payment.success',
      data: {
        reference: 'MTX-123',
        amount: 1500,
        currency: 'XOF',
        metadata: { user_id: 'user-1', kind: 'SUBSCRIPTION' },
      },
    });
    const timestamp = String(Math.floor(Date.now() / 1000));
    const signature = createHmac('sha256', secret).update(`${timestamp}.${rawBody}`).digest('hex');
    const single = jest.fn().mockResolvedValue({
      data: { id: 'payment-1', status: 'SUCCEEDED', provider_reference: 'MTX-123' },
      error: null,
    });
    const maybeSingle = jest
      .fn()
      .mockResolvedValueOnce({
        data: {
          id: 'payment-1',
          status: 'PENDING',
          provider_reference: 'MTX-123',
          amount: 1500,
          user_id: 'user-1',
          kind: 'SUBSCRIPTION',
          subscription_id: null,
        },
        error: null,
      })
      .mockResolvedValueOnce({ data: null, error: null });
    const update = jest.fn().mockReturnValue({
      eq: jest.fn().mockReturnValue({
        eq: jest.fn().mockResolvedValue({ error: null }),
      }),
    });
    const upsert = jest.fn().mockReturnValue({
      select: jest.fn().mockReturnValue({ single }),
    });
    const from = jest.fn().mockReturnValue({
      select: jest.fn().mockReturnValue({
        eq: jest.fn().mockReturnValue({
          eq: jest.fn().mockReturnValue({ maybeSingle }),
        }),
      }),
      upsert,
      update,
    });
    const config = { get: jest.fn().mockReturnValue(secret) } as unknown as AppConfigService;
    const supabase = { admin: { from } } as unknown as SupabaseService;
    const service = new GeniusPayWebhookService(config, supabase);

    await expect(service.handle(rawBody, signature, timestamp, 'payment.success')).resolves.toEqual(
      {
        received: true,
        payment: { id: 'payment-1', status: 'SUCCEEDED', provider_reference: 'MTX-123' },
      },
    );
    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({ provider_reference: 'MTX-123', status: 'SUCCEEDED' }),
      { onConflict: 'provider,provider_reference' },
    );
  });
});
