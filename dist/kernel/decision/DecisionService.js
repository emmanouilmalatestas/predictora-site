"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DecisionService = void 0;
class DecisionService {
    constructor(bus) {
        this.bus = bus;
    }
    async createDecision(input) {
        await this.bus.publish({
            name: 'DecisionCreated',
            timestamp: new Date().toISOString(),
            payload: {
                id: input.incidentId,
                risk: input.risk,
                impact: input.impact,
                recommendation: input.recommendation,
            },
        });
    }
    async approveDecision(decisionId, userId) {
        await this.bus.publish({
            name: 'DecisionApproved',
            timestamp: new Date().toISOString(),
            payload: {
                id: decisionId,
                userId,
            },
        });
    }
    async executeDecision(decisionId) {
        await this.bus.publish({
            name: 'DecisionExecuted',
            timestamp: new Date().toISOString(),
            payload: {
                id: decisionId,
            },
        });
    }
}
exports.DecisionService = DecisionService;
