import { Pool } from 'pg';
import { ReplayStore } from './ReplayStore';

export class PostgresReplayStore implements ReplayStore {
  constructor(private pool: Pool) {}

  async saveReplayEvent(event: {
    incidentId: string;
    state: string;
    timestamp: string;
    payload: any;
  }): Promise<void> {
    await this.pool.query(
      `INSERT INTO replay_events (incident_id, state, timestamp, payload)
       VALUES ($1, $2, $3, $4)`,
      [
        event.incidentId,
        event.state,
        event.timestamp,
        JSON.stringify(event.payload),
      ]
    );
  }

  async getReplayHistory(incidentId: string): Promise<any[]> {
    const result = await this.pool.query(
      `SELECT incident_id, state, timestamp, payload
       FROM replay_events
       WHERE incident_id = $1
       ORDER BY timestamp ASC`,
      [incidentId]
    );

    return result.rows;
  }
}
