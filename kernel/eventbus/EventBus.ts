export type EventName =
  | 'IncidentDetected'
  | 'ReplayStarted'
  | 'ReplayCompleted'
  | 'RootCauseIdentified'
  | 'DecisionCreated'
  | 'DecisionApproved'
  | 'DecisionExecuted'
  | 'WorkerStarted'
  | 'WorkerFailed'
  | 'AutomationExecuted'
  | 'KnowledgeUpdated'
  | 'RevenueCalculated'
  | 'ComplianceVerified';

export interface Event<TPayload = any> {
  name: EventName;
  timestamp: string;
  payload: TPayload;
}

export type EventHandler = (event: Event) => Promise<void> | void;

export interface EventBus {
  publish(event: Event): Promise<void>;
  subscribe(name: EventName, handler: EventHandler): void;
}
