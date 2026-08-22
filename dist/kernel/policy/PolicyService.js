"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PolicyService = void 0;
class PolicyService {
    evaluate(policyName, context) {
        switch (policyName) {
            case 'approval':
                return this.canApproveIncident(context);
            case 'decision_proposal':
                return this.canProposeDecision(context);
            default:
                return false;
        }
    }
    canApproveIncident(context) {
        if (context.roles.includes('admin'))
            return true;
        if (context.roles.includes('incident_manager'))
            return true;
        return false;
    }
    canProposeDecision(context) {
        if (context.roles.includes('admin'))
            return true;
        if (context.roles.includes('architect'))
            return true;
        return false;
    }
}
exports.PolicyService = PolicyService;
