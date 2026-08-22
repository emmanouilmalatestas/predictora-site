"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const InMemoryEventBus_1 = require("./eventbus/InMemoryEventBus");
const RuntimeService_1 = require("./runtime/RuntimeService");
const ReplayService_1 = require("./replay/ReplayService");
const DecisionService_1 = require("./decision/DecisionService");
const PolicyService_1 = require("./policy/PolicyService");
const IdentityService_1 = require("./identity/IdentityService");
const PostgresReplayStore_1 = require("./replay/PostgresReplayStore");
const pg_1 = require("pg");
const CapabilityService_1 = require("./capability/CapabilityService");
// Event Bus (shared across entire PredictoraOS)
const bus = new InMemoryEventBus_1.InMemoryEventBus();
// PostgreSQL Replay Storage
const pool = new pg_1.Pool({
    host: 'predictoraai-db',
    user: 'predictora',
    password: 'predictora',
    database: 'predictora',
});
const replayStore = new PostgresReplayStore_1.PostgresReplayStore(pool);
// Core Kernel Services
const runtime = new RuntimeService_1.RuntimeService(bus);
const replay = new ReplayService_1.ReplayService(bus, replayStore);
const decision = new DecisionService_1.DecisionService(bus);
const policy = new PolicyService_1.PolicyService();
const identity = new IdentityService_1.IdentityService();
const capability = new CapabilityService_1.CapabilityService(bus);
// Kernel bootstrap (optional demo flow)
async function bootstrap() {
    // Simulate an incident detection
    await runtime.reportIncident({
        id: 'inc-bootstrap',
        capabilityId: 'bootstrap_test',
        severity: 'critical',
    });
    // Record replay start
    await replay.startReplay('inc-bootstrap');
    // Record replay step
    await replay.recordReplayStep('inc-bootstrap', 'ReplayRunning', {
        userId: 'system',
    });
    // Create a decision
    await decision.createDecision({
        incidentId: 'inc-bootstrap',
        risk: 0.5,
        impact: 10000,
        recommendation: 'restart_service',
    });
    await capability.emitCapabilityIncident({
        id: 'cap-1',
        capabilityId: 'payments',
        severity: 'critical',
        details: { timeout: true }
    });
    // Approve decision
    await decision.approveDecision('inc-bootstrap', 'system');
    // Execute decision
    await decision.executeDecision('inc-bootstrap');
}
bootstrap().catch((err) => {
    console.error('Kernel bootstrap error:', err);
});
