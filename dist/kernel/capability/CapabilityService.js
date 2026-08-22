"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CapabilityService = void 0;
class CapabilityService {
    constructor(bus) {
        this.bus = bus;
    }
    async emitCapabilityIncident(input) {
        await this.bus.publish({
            name: 'IncidentDetected',
            timestamp: new Date().toISOString(),
            payload: {
                id: input.id,
                capabilityId: input.capabilityId,
                severity: input.severity,
                details: input.details ?? {},
            },
        });
    }
}
exports.CapabilityService = CapabilityService;
