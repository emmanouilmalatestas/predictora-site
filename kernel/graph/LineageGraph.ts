export class LineageGraph {
  async build(executionId: string) {
    return {
      executionId,
      entity: { id: executionId },
      event: { id: `evt_${executionId}` },
      signal: { id: `sig_${executionId}` },
      prediction: { id: `pred_${executionId}` },
      decision: { id: `dec_${executionId}` },
      action: { id: `act_${executionId}` },
      outcome: { id: `out_${executionId}` }
    };
  }
}
