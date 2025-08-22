export class AccessControlService {
  async checkAccess(params: {
    userId: string;
    resourceId: string;
    resourceType: ResourceType;
    action: Action;
  }): Promise<AccessDecision> {
    // Get user's roles and permissions
    const user = await this.getUser(params.userId);
    const permissions = await this.getUserPermissions(user);

    // Get resource permissions
    const resource = await this.getResource(
      params.resourceId,
      params.resourceType,
    );
    const resourcePermissions = resource.permissions;

    // Check ownership
    if (resource.ownerId === params.userId) {
      return AccessDecision.allow("owner");
    }

    // Check explicit permissions
    const userResourcePermission = resourcePermissions.users?.[params.userId];
    if (userResourcePermission) {
      if (this.hasPermission(userResourcePermission, params.action)) {
        return AccessDecision.allow("explicit");
      }
    }

    // Check team permissions
    for (const team of user.teams) {
      const teamPermission = resourcePermissions.teams?.[team.id];
      if (teamPermission && this.hasPermission(teamPermission, params.action)) {
        return AccessDecision.allow("team", team.name);
      }
    }

    // Check role-based permissions
    for (const role of user.roles) {
      if (this.roleHasPermission(role, params.resourceType, params.action)) {
        return AccessDecision.allow("role", role.name);
      }
    }

    // Check subscription tier permissions
    const tierPermissions = this.getTierPermissions(user.subscription?.tier);
    if (tierPermissions.includes(params.action)) {
      return AccessDecision.allow("subscription");
    }

    return AccessDecision.deny("No permission");
  }

  async shareResource(params: {
    resourceId: string;
    resourceType: ResourceType;
    sharedBy: string;
    sharedWith: string | string[];
    permissions: Permission[];
    expiresAt?: Date;
  }): Promise<ShareResult> {
    // Validate sharing permissions
    const canShare = await this.checkAccess({
      userId: params.sharedBy,
      resourceId: params.resourceId,
      resourceType: params.resourceType,
      action: "share",
    });

    if (!canShare.allowed) {
      throw new ForbiddenError("Cannot share resource");
    }

    // Create share records
    const shares = [];
    const recipients = Array.isArray(params.sharedWith)
      ? params.sharedWith
      : [params.sharedWith];

    for (const recipient of recipients) {
      const share = await prisma.share.create({
        data: {
          resourceId: params.resourceId,
          resourceType: params.resourceType,
          sharedBy: params.sharedBy,
          sharedWith: recipient,
          permissions: params.permissions,
          expiresAt: params.expiresAt,
        },
      });
      shares.push(share);

      // Send notification
      await this.notifyShare(recipient, params.resourceId, params.sharedBy);
    }

    return { shares, success: true };
  }
}
