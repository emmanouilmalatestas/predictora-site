import { EventBus, Event } from '../eventbus/EventBus';
import { TraceService } from '../trace/TraceService';
import { ReplayService } from '../replay/ReplayService';
import { LineageGraph } from '../graph/LineageGraph';
import { ValueAttributionService } from '../value/ValueAttributionService';

export class RuntimeService {
  private traceService: TraceService;

  constructor(private bus: EventBus) {
    const replay = new ReplayService();
    const lineage = new LineageGraph();
    const value = new ValueAttributionService();
    this.traceService = new TraceService(replay, lineage, value);
  }

  async execute(context: any) {
    const event: Event = {
      name: 'ExecutionStarted',
      timestamp: new Date().toISOString(),
      payload: context
    };
    await this.bus.publish(event);
    return { status: 'ok', executionId: context.id };
  }

  async trace(executionId: string) {
    return await this.traceService.buildTrace(executionId);
  }

  async replay(executionId: string) {
    return await this.traceService.replay.runReplay(executionId);
  }

  async lineage(executionId: string) {
    return await this.traceService.lineage.build(executionId);
  }

  async value(executionId: string) {
    return await this.traceService.value.calculate(executionId);
  }

  async reportIncident(incident: any) {
    const event: Event = {
      name: 'IncidentDetected',
      timestamp: new Date().toISOString(),
      payload: incident
    };
    await this.bus.publish(event);
  }

  async getOverview() {
    return {
      health: 'healthy',
      incidents: 0,
      workers: 12,
      metrics: {
        latency: 120,
        errorRate: 0.2,
        throughput: 14000
      }
    };
  }
}
