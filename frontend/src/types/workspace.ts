export interface Workspace {
  id: string;
  name: string;
  color: string;
  project_count: number;
  created_at: string;
  updated_at: string;
}

export interface WorkspaceCreate {
  name: string;
  color: string;
}

export interface WorkspaceUpdate extends Partial<WorkspaceCreate> {}
