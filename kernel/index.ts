import { InMemoryEventBus } from './eventbus/InMemoryEventBus';
import { RuntimeService } from './runtime/RuntimeService';
import { ReplayService } from './replay/ReplayService';
import { DecisionService } from './decision/DecisionService';
import { PolicyService } from './policy/PolicyService';
import { IdentityService } from './identity/IdentityService';
import { PostgresReplayStore } from './replay/PostgresReplayStore';
import { Pool } from 'pg';
import { CapabilityService } from './capability/CapabilityService';

// Event Bus (shared across entire PredictoraOS)
const bus = new InMemoryEventBus();

// PostgreSQL Replay Storage
const pool = new Pool({
  host: 'predictoraai-db',
  user: 'predictora',
  password: 'predictora',
  database: 'predictora',
});

const replayStore = new PostgresReplayStore(pool);

// Core Kernel Services
const runtime = new RuntimeService(bus);
const replay = new ReplayService(bus, replayStore);
const decision = new DecisionService(bus);
const policy = new PolicyService();
const identity = new IdentityService();
const capability = new CapabilityService(bus);

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
