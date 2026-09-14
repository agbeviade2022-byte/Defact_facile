import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AiWallet } from './wallet.entity';
import { AiWalletTransaction } from './wallet-transaction.entity';
import { UsersService } from '../../users/users.service';

@Injectable()
export class WalletService {
  constructor(
    @InjectRepository(AiWallet)
    private walletRepository: Repository<AiWallet>,
    @InjectRepository(AiWalletTransaction)
    private transactionRepository: Repository<AiWalletTransaction>,
    private usersService: UsersService,
  ) {}

  /**
   * Obtenir ou créer le wallet IA pour un utilisateur
   */
  async getOrCreateWallet(userId: string): Promise<AiWallet> {
    let wallet = await this.walletRepository.findOne({ where: { userId } });

    if (!wallet) {
      // Vérifier que l'utilisateur existe
      const user = await this.usersService.findById(userId);
      if (!user) {
        throw new NotFoundException(`User not found: ${userId}`);
      }

      // Créer un nouveau wallet avec un solde initial de 0
      wallet = this.walletRepository.create({
        userId,
        balanceTokens: 0,
      });
      wallet = await this.walletRepository.save(wallet);
    }

    return wallet;
  }

  /**
   * Obtenir le solde actuel du wallet en jetons
   */
  async getBalance(userId: string): Promise<number> {
    const wallet = await this.getOrCreateWallet(userId);
    return wallet.balanceTokens;
  }

  /**
   * Attribuer le bonus gratuit unique de 500 jetons IA
   * Retourne true si le bonus a été attribué, false s'il avait déjà été attribué auparavant
   * Utilise plusieurs signaux pour prévenir les abus : userId, email, googleId
   */
  async grantFreeTrialBonus(userId: string): Promise<boolean> {
    // 1. Vérifier si l'utilisateur a déjà reçu le bonus gratuit via une transaction
    const existingBonus = await this.transactionRepository.findOne({
      where: {
        userId,
        type: 'FREE_TRIAL_CREDIT',
      },
    });

    if (existingBonus) {
      // Le bonus a déjà été attribué
      return false;
    }

    // 2. Récupérer l'utilisateur pour vérifier les signaux email et googleId
    const user = await this.usersService.findById(userId);
    if (!user) {
      throw new Error('User not found');
    }

    // 3. Vérifier le flag freeBonusGranted sur l'utilisateur
    if (user.freeBonusGranted) {
      return false;
    }

    // 4. Vérifier si un autre utilisateur avec le même email a déjà reçu le bonus
    if (user.email) {
      const otherUserByEmail = await this.usersService.findByEmail(user.email);
      if (
        otherUserByEmail &&
        otherUserByEmail.id !== userId &&
        otherUserByEmail.freeBonusGranted
      ) {
        return false;
      }
    }

    // 5. Vérifier si un autre utilisateur avec le même googleId a déjà reçu le bonus
    if (user.googleId) {
      const otherUserByGoogle = await this.usersService.findByGoogleId(user.googleId);
      if (
        otherUserByGoogle &&
        otherUserByGoogle.id !== userId &&
        otherUserByGoogle.freeBonusGranted
      ) {
        return false;
      }
    }

    // 6. Obtenir le wallet de l'utilisateur
    const wallet = await this.getOrCreateWallet(userId);
    const balanceBefore = wallet.balanceTokens;

    // 7. Créer la transaction de bonus
    const bonusTransaction = this.transactionRepository.create({
      userId,
      walletId: wallet.id,
      type: 'FREE_TRIAL_CREDIT',
      tokensAmount: 500,
      balanceBefore,
      balanceAfter: balanceBefore + 500,
    });

    // 8. Sauvegarder la transaction
    await this.transactionRepository.save(bonusTransaction);

    // 9. Mettre à jour le solde du wallet
    wallet.balanceTokens += 500;
    await this.walletRepository.save(wallet);

    // 10. Marquer l'utilisateur comme ayant reçu le bonus (pour prévenir les abus futurs)
    await this.usersService.setFreeBonusGranted(userId, true);

    return true;
  }

  /**
   * Créditer des jetons dans le wallet (ex: après paiement d'abonnement ou recharge)
   */
  async creditTokens(
    userId: string,
    tokensAmount: number,
    type: 'AI_TOKEN_CREDIT' | 'AI_TOKEN_REFUND' | 'AI_TOKEN_ADJUSTMENT' | 'AI_TOKEN_BONUS' | 'GENIUSPAY_PAYMENT',
    subscriptionId?: number,
    paymentId?: number,
    feature?: string,
    provider?: string,
    providerCostFcfa?: number,
    reference?: string,
    metadata?: string,
  ): Promise<AiWalletTransaction> {
    const wallet = await this.getOrCreateWallet(userId);
    const balanceBefore = wallet.balanceTokens;

    // Créer la transaction
    const transaction = this.transactionRepository.create({
      userId,
      walletId: wallet.id,
      type,
      tokensAmount,
      balanceBefore,
      balanceAfter: balanceBefore + tokensAmount,
      subscriptionId,
      paymentId,
      feature,
      provider,
      providerCostFcfa,
      reference,
      metadata,
    });

    // Sauvegarder la transaction
    const savedTransaction = await this.transactionRepository.save(transaction);

    // Mettre à jour le solde du wallet
    wallet.balanceTokens += tokensAmount;
    await this.walletRepository.save(wallet);

    return savedTransaction;
  }

  /**
   * Utiliser des jetons du wallet (ex: après appel à l'IA)
   * Retourne true si l'opération a réussi, false si solde insuffisant
   */
  async useTokens(
    userId: string,
    tokensAmount: number,
    feature?: string,
    provider?: string,
    providerCostFcfa?: number,
    reference?: string,
    metadata?: string,
  ): Promise<boolean> {
    const wallet = await this.getOrCreateWallet(userId);

    if (wallet.balanceTokens < tokensAmount) {
      // Solde insuffisant
      return false;
    }

    const balanceBefore = wallet.balanceTokens;

    // Créer la transaction d'utilisation
    const transaction = this.transactionRepository.create({
      userId,
      walletId: wallet.id,
      type: 'AI_TOKEN_USAGE',
      tokensAmount: -tokensAmount, // Négatif pour indiquer une utilisation
      balanceBefore,
      balanceAfter: balanceBefore - tokensAmount,
      feature,
      provider,
      providerCostFcfa,
      reference,
      metadata,
    });

    // Sauvegarder la transaction
    await this.transactionRepository.save(transaction);

    // Mettre à jour le solde du wallet
    wallet.balanceTokens -= tokensAmount;
    await this.walletRepository.save(wallet);

    return true;
  }

  /**
   * Obtenir l'historique des transactions d'un utilisateur
   */
  async getTransactionHistory(userId: string, limit: number = 50): Promise<AiWalletTransaction[]> {
    return this.transactionRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }
}