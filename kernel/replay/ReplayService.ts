import { EventBus } from '../eventbus/EventBus';
import { ReplayStore } from './ReplayStore';

export class ReplayService {
  constructor(
    private bus: EventBus,
    private store: ReplayStore
  ) {}

  async startReplay(incidentId: string) {
    await this.store.saveReplayEvent({
      incidentId,
      state: 'ReplayStarted',
      timestamp: new Date().toISOString(),
      payload: {},
    });

    await this.bus.publish({
      name: 'ReplayStarted',
      timestamp: new Date().toISOString(),
      payload: { id: incidentId },
    });
  }

  async recordReplayStep(
    incidentId: string,
    state: string,
    payload: any
  ) {
    await this.store.saveReplayEvent({
      incidentId,
      state,
      timestamp: new Date().toISOString(),
      payload,
    });
  }
}
