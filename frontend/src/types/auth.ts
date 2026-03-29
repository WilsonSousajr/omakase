export interface User {
  id: number;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
  avatar_color: string;
  date_joined: string;
}

export interface AuthTokens {
  access: string;
  refresh: string;
}

export interface GoogleAuthResponse {
  access: string;
  refresh: string;
  user: User;
}

export interface UpdateProfilePayload {
  first_name?: string;
  last_name?: string;
  email?: string;
  avatar_color?: string;
}
