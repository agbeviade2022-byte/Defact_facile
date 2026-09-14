import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AntiAbuseEvent } from './anti_abuse_event.entity';
import { DeviceInstallation } from './device_installation.entity';
import { User } from '../users/user.entity';

@Injectable()
export class AntiAbuseService {
  constructor(
    @InjectRepository(AntiAbuseEvent)
    private antiAbuseEventsRepository: Repository<AntiAbuseEvent>,
    @InjectRepository(DeviceInstallation)
    private deviceInstallationsRepository: Repository<DeviceInstallation>,
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async logEvent(eventData: Partial<AntiAbuseEvent>): Promise<AntiAbuseEvent> {
    const event = this.antiAbuseEventsRepository.create(eventData);
    return this.antiAbuseEventsRepository.save(event);
  }

  async registerDeviceInstallation(installationData: Partial<DeviceInstallation>): Promise<DeviceInstallation> {
    // Check if device already exists
    const existingDevice = await this.deviceInstallationsRepository.findOne({
      where: { installationId: installationData.installationId }
    });

    if (existingDevice) {
      // Update existing device
      await this.deviceInstallationsRepository.update(existingDevice.id, {
        ...installationData,
        lastSeenAt: new Date(),
      });
      const updatedDevice = await this.deviceInstallationsRepository.findOne({ where: { id: existingDevice.id } });
      if (!updatedDevice) {
        throw new Error('Failed to retrieve updated device installation');
      }
      return updatedDevice;
    } else {
      // Create new device installation
      const deviceInstallation = this.deviceInstallationsRepository.create({
        ...installationData,
        lastSeenAt: new Date(),
      });
      return this.deviceInstallationsRepository.save(deviceInstallation);
    }
  }

  async getDeviceInstallation(installationId: string): Promise<DeviceInstallation | null> {
    return this.deviceInstallationsRepository.findOne({ where: { installationId } });
  }

  async blockDevice(installationId: string, reason: string): Promise<DeviceInstallation> {
    const device = await this.getDeviceInstallation(installationId);
    if (!device) {
      throw new Error('Device installation not found');
    }

    device.isBlocked = true;
    device.blockedReason = reason;
    return this.deviceInstallationsRepository.save(device);
  }

  async unblockDevice(installationId: string): Promise<DeviceInstallation> {
    const device = await this.getDeviceInstallation(installationId);
    if (!device) {
      throw new Error('Device installation not found');
    }

    device.isBlocked = false;
    device.blockedReason = null;
    return this.deviceInstallationsRepository.save(device);
  }

  async getEvents(options: any = {}): Promise<AntiAbuseEvent[]> {
    const query = this.antiAbuseEventsRepository.createQueryBuilder('event')
      .leftJoinAndSelect('event.user', 'user')
      .leftJoinAndSelect('event.deviceInstallation', 'device');

    // Apply filters
    if (options.eventType) {
      query.andWhere('event.eventType = :eventType', { eventType: options.eventType });
    }

    if (options.severity) {
      query.andWhere('event.severity = :severity', { severity: options.severity });
    }

    if (options.isResolved !== undefined) {
      query.andWhere('event.isResolved = :isResolved', { isResolved: options.isResolved });
    }

    if (options.userId) {
      query.andWhere('event.userId = :userId', { userId: options.userId });
    }

    if (options.deviceId) {
      query.andWhere('event.deviceInstallationId = :deviceId', { deviceId: options.deviceId });
    }

    // Apply date range filter
    if (options.startDate && options.endDate) {
      query.andWhere('event.createdAt BETWEEN :startDate AND :endDate', { startDate: options.startDate, endDate: options.endDate });
    } else if (options.startDate) {
      query.andWhere('event.createdAt >= :startDate', { startDate: options.startDate });
    } else if (options.endDate) {
      query.andWhere('event.createdAt <= :endDate', { endDate: options.endDate });
    }

    // Apply pagination
    if (options.limit) {
      query.take(options.limit);
    }
    if (options.offset) {
      query.skip(options.offset);
    }

    // Order by creation date descending (newest first)
    query.orderBy('event.createdAt', 'DESC');

    return query.getMany();
  }

  async getEventCount(options: any = {}): Promise<number> {
    const query = this.antiAbuseEventsRepository.createQueryBuilder('event');

    // Apply filters (same as getEvents but without pagination)
    if (options.eventType) {
      query.andWhere('event.eventType = :eventType', { eventType: options.eventType });
    }

    if (options.severity) {
      query.andWhere('event.severity = :severity', { severity: options.severity });
    }

    if (options.isResolved !== undefined) {
      query.andWhere('event.isResolved = :isResolved', { isResolved: options.isResolved });
    }

    if (options.userId) {
      query.andWhere('event.userId = :userId', { userId: options.userId });
    }

    if (options.deviceId) {
      query.andWhere('event.deviceInstallationId = :deviceId', { deviceId: options.deviceId });
    }

    // Apply date range filter
    if (options.startDate && options.endDate) {
      query.andWhere('event.createdAt BETWEEN :startDate AND :endDate', { startDate: options.startDate, endDate: options.endDate });
    } else if (options.startDate) {
      query.andWhere('event.createdAt >= :startDate', { startDate: options.startDate });
    } else if (options.endDate) {
      query.andWhere('event.createdAt <= :endDate', { endDate: options.endDate });
    }

    return query.getCount();
  }
}