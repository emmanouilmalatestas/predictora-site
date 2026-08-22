"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ReplayService = void 0;
class ReplayService {
    constructor(bus, store) {
        this.bus = bus;
        this.store = store;
    }
    async startReplay(incidentId) {
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
    async recordReplayStep(incidentId, state, payload) {
        await this.store.saveReplayEvent({
            incidentId,
            state,
            timestamp: new Date().toISOString(),
            payload,
        });
    }
}
exports.ReplayService = ReplayService;
