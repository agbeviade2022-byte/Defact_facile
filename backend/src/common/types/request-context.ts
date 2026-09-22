import { Request } from 'express';
import { Permission } from '../constants/permissions';

/** Identity resolved from a Supabase or DEFACT access token. */
export interface AuthenticatedUser {
  id: string;
  email: string | null;
  accessToken: string;
}

/** Tenant resolved from the `X-Workspace-Id` header + membership check (Mission 03). */
export type WorkspaceKind = 'personal' | 'organization';

export interface WorkspaceContext {
  kind: WorkspaceKind;
  id: string;
  roleId: string | null;
  permissions: ReadonlySet<Permission>;
}

export interface RequestContext extends Request {
  user?: AuthenticatedUser;
  workspace?: WorkspaceContext;
}
