export interface Tag {
  id: string;
  name: string;
  color: string;
  area: "work" | "personal" | "study";
  created_at: string;
}

export interface TagCreate {
  name: string;
  color: string;
  area: "work" | "personal" | "study";
}
