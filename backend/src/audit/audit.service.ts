import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AuditLog } from './audit_log.entity';
import { User } from '../users/user.entity';

@Injectable()
export class AuditService {
  constructor(
    @InjectRepository(AuditLog)
    private auditLogsRepository: Repository<AuditLog>,
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async logAction(auditData: Partial<AuditLog>): Promise<AuditLog> {
    const auditLog = this.auditLogsRepository.create(auditData);
    return this.auditLogsRepository.save(auditLog);
  }

  async logUserAction(userId: string, action: string, entityType: string, entityId: string | null = null, changes: string | null = null, ipAddress: string | null = null, userAgent: string | null = null): Promise<AuditLog> {
    const user = await this.usersRepository.findOne({ where: { id: userId } });
    if (!user) {
      throw new Error('User not found');
    }

    const auditLog = this.auditLogsRepository.create({
      user,
      action,
      entityType,
      entityId,
      changes,
      ipAddress,
      userAgent,
    });

    return this.auditLogsRepository.save(auditLog);
  }

  async getLogs(options: any = {}): Promise<AuditLog[]> {
    const query = this.auditLogsRepository.createQueryBuilder('auditLog')
      .leftJoinAndSelect('auditLog.user', 'user');

    // Apply filters
    if (options.userId) {
      query.andWhere('auditLog.userId = :userId', { userId: options.userId });
    }

    if (options.entityType) {
      query.andWhere('auditLog.entityType = :entityType', { entityType: options.entityType });
    }

    if (options.entityId) {
      query.andWhere('auditLog.entityId = :entityId', { entityId: options.entityId });
    }

    if (options.action) {
      query.andWhere('auditLog.action = :action', { action: options.action });
    }

    // Apply date range filter
    if (options.startDate && options.endDate) {
      query.andWhere('auditLog.createdAt BETWEEN :startDate AND :endDate', { startDate: options.startDate, endDate: options.endDate });
    } else if (options.startDate) {
      query.andWhere('auditLog.createdAt >= :startDate', { startDate: options.startDate });
    } else if (options.endDate) {
      query.andWhere('auditLog.createdAt <= :endDate', { endDate: options.endDate });
    }

    // Apply pagination
    if (options.limit) {
      query.take(options.limit);
    }
    if (options.offset) {
      query.skip(options.offset);
    }

    // Order by creation date descending (newest first)
    query.orderBy('auditLog.createdAt', 'DESC');

    return query.getMany();
  }

  async getLogCount(options: any = {}): Promise<number> {
    const query = this.auditLogsRepository.createQueryBuilder('auditLog');

    // Apply filters (same as getLogs but without pagination)
    if (options.userId) {
      query.andWhere('auditLog.userId = :userId', { userId: options.userId });
    }

    if (options.entityType) {
      query.andWhere('auditLog.entityType = :entityType', { entityType: options.entityType });
    }

    if (options.entityId) {
      query.andWhere('auditLog.entityId = :entityId', { entityId: options.entityId });
    }

    if (options.action) {
      query.andWhere('auditLog.action = :action', { action: options.action });
    }

    // Apply date range filter
    if (options.startDate && options.endDate) {
      query.andWhere('auditLog.createdAt BETWEEN :startDate AND :endDate', { startDate: options.startDate, endDate: options.endDate });
    } else if (options.startDate) {
      query.andWhere('auditLog.createdAt >= :startDate', { startDate: options.startDate });
    } else if (options.endDate) {
      query.andWhere('auditLog.createdAt <= :endDate', { endDate: options.endDate });
    }

    return query.getCount();
  }

  async removeOldLogs(daysToKeep: number = 365): Promise<void> {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);

    await this.auditLogsRepository.delete({
      createdAt: cutoffDate
    });
  }
}