import { EventBus } from '../eventbus/EventBus';

export class CapabilityService {
  constructor(private bus: EventBus) {}

  async emitCapabilityIncident(input: {
    id: string;
    capabilityId: string;
    severity: 'low' | 'medium' | 'high' | 'critical';
    details?: any;
  }) {
    await this.bus.publish({
      name: 'IncidentDetected',
      timestamp: new Date().toISOString(),
      payload: {
        id: input.id,
        capabilityId: input.capabilityId,
        severity: input.severity,
        details: input.details ?? {},
      },
    });
  }
}
