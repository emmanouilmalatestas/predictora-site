export interface ReplayStore {
  saveReplayEvent(event: {
    incidentId: string;
    state: string;
    timestamp: string;
    payload: any;
  }): Promise<void>;

  getReplayHistory(incidentId: string): Promise<any[]>;
}
