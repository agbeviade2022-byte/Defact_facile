import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn } from 'typeorm';

@Entity('ai_wallet_transactions')
export class AiWalletTransaction {
  @PrimaryGeneratedColumn()
  id: number;

  @Column()
  userId: string;

  @Column()
  walletId: number;

  @Column({
    enum: ['AI_TOKEN_CREDIT', 'AI_TOKEN_USAGE', 'AI_TOKEN_REFUND', 'AI_TOKEN_ADJUSTMENT', 'AI_TOKEN_BONUS', 'AI_TOKEN_EXPIRATION', 'FREE_TRIAL_CREDIT', 'GENIUSPAY_PAYMENT']
  })
  type: string;

  @Column({ type: 'int' })
  tokensAmount: number; // Peut être négatif pour les usages/ajustements

  @Column({ type: 'int' })
  balanceBefore: number;

  @Column({ type: 'int' })
  balanceAfter: number;

  @Column({ nullable: true })
  subscriptionId: number;

  @Column({ nullable: true })
  paymentId: number;

  @Column({ nullable: true })
  feature: string;

  @Column({ nullable: true })
  provider: string; // 'claude' ou 'openai'

  @Column({ type: 'decimal', precision: 10, scale: 2, nullable: true })
  providerCostFcfa: number; // Coût réel du fournisseur en FCFA

  @Column({ nullable: true })
  reference: string; // Référence externe (ex: ID de transaction GeniusPay)

  @Column({ type: 'text', nullable: true })
  metadata: string; // JSON stocké comme texte

  @CreateDateColumn()
  createdAt: Date;
}