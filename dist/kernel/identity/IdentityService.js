"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.IdentityService = void 0;
class IdentityService {
    async getUserRoles(userId) {
        if (!userId || userId === 'unknown') {
            return ['guest'];
        }
        if (userId === 'emmanouil') {
            return ['admin', 'architect', 'incident_manager'];
        }
        return ['user'];
    }
}
exports.IdentityService = IdentityService;
