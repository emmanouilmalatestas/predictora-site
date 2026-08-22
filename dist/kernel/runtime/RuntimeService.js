"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RuntimeService = void 0;
class RuntimeService {
    constructor(bus) {
        this.bus = bus;
    }
    async reportIncident(incident) {
        const event = {
            name: 'IncidentDetected',
            timestamp: new Date().toISOString(),
            payload: incident,
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
                throughput: 14000,
            },
        };
    }
}
exports.RuntimeService = RuntimeService;
