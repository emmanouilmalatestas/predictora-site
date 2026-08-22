import { EventBus } from '../eventbus/EventBus';

export class DecisionService {
  constructor(private bus: EventBus) {}

  async createDecision(input: {
    incidentId: string;
    risk: number;
    impact: number;
    recommendation: string;
  }) {
    await this.bus.publish({
      name: 'DecisionCreated',
      timestamp: new Date().toISOString(),
      payload: {
        id: input.incidentId,
        risk: input.risk,
        impact: input.impact,
        recommendation: input.recommendation,
      },
    });
  }

  async approveDecision(decisionId: string, userId: string) {
    await this.bus.publish({
      name: 'DecisionApproved',
      timestamp: new Date().toISOString(),
      payload: {
        id: decisionId,
        userId,
      },
    });
  }

  async executeDecision(decisionId: string) {
    await this.bus.publish({
      name: 'DecisionExecuted',
      timestamp: new Date().toISOString(),
      payload: {
        id: decisionId,
      },
    });
  }
}
