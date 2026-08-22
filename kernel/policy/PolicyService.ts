export type PolicyContext = {
  userId: string;
  roles: string[];
  incidentId?: string;
};

export class PolicyService {
  evaluate(policyName: string, context: PolicyContext): boolean {
    switch (policyName) {
      case 'approval':
        return this.canApproveIncident(context);
      case 'decision_proposal':
        return this.canProposeDecision(context);
      default:
        return false;
    }
  }

  private canApproveIncident(context: PolicyContext): boolean {
    if (context.roles.includes('admin')) return true;
    if (context.roles.includes('incident_manager')) return true;
    return false;
  }

  private canProposeDecision(context: PolicyContext): boolean {
    if (context.roles.includes('admin')) return true;
    if (context.roles.includes('architect')) return true;
    return false;
  }
}
