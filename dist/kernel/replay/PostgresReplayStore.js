"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PostgresReplayStore = void 0;
class PostgresReplayStore {
    constructor(pool) {
        this.pool = pool;
    }
    async saveReplayEvent(event) {
        await this.pool.query(`INSERT INTO replay_events (incident_id, state, timestamp, payload)
       VALUES ($1, $2, $3, $4)`, [
            event.incidentId,
            event.state,
            event.timestamp,
            JSON.stringify(event.payload),
        ]);
    }
    async getReplayHistory(incidentId) {
        const result = await this.pool.query(`SELECT incident_id, state, timestamp, payload
       FROM replay_events
       WHERE incident_id = $1
       ORDER BY timestamp ASC`, [incidentId]);
        return result.rows;
    }
}
exports.PostgresReplayStore = PostgresReplayStore;
