export class IdentityService {
  async getUserRoles(userId: string): Promise<string[]> {
    if (!userId || userId === 'unknown') {
      return ['guest'];
    }

    if (userId === 'emmanouil') {
      return ['admin', 'architect', 'incident_manager'];
    }

    return ['user'];
  }
}
