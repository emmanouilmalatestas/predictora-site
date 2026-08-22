import { ReplayService } from '../replay/ReplayService';
import { LineageGraph } from '../graph/LineageGraph';
import { ValueAttributionService } from '../value/ValueAttributionService';

export class TraceService {
  constructor(
    private replay: ReplayService,
    private lineage: LineageGraph,
    private value: ValueAttributionService
  ) {}

  async buildTrace(executionId: string) {
    const lineageGraph = await this.lineage.build(executionId);
    const replayResult = await this.replay.runReplay(executionId);
    const value = await this.value.calculate(executionId);

    return {
      executionId,
      lineage: lineageGraph,
      replay: replayResult,
      value
    };
  }
}
