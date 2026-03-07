import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";

import api from "@/lib/api";
import { useAuthStore } from "@/stores/authStore";
import type {
  AuthTokens,
  LoginCredentials,
  RegisterCredentials,
  User,
} from "@/types/auth";

export function useMe() {
  const isAuthenticated = useAuthStore((s) => s.isAuthenticated);
  const setUser = useAuthStore((s) => s.setUser);

  return useQuery({
    queryKey: ["auth", "me"],
    queryFn: async () => {
      const { data } = await api.get<User>("/auth/me/");
      setUser(data);
      return data;
    },
    enabled: isAuthenticated,
    retry: false,
    staleTime: 5 * 60 * 1000,
  });
}

export function useLogin() {
  const setAuth = useAuthStore((s) => s.setAuth);
  const router = useRouter();

  return useMutation({
    mutationFn: async (credentials: LoginCredentials) => {
      const { data: tokens } = await api.post<AuthTokens>(
        "/auth/token/",
        credentials
      );
      const { data: user } = await api.get<User>("/auth/me/", {
        headers: { Authorization: `Bearer ${tokens.access}` },
      });
      return { user, tokens };
    },
    onSuccess: ({ user, tokens }) => {
      setAuth(user, tokens);
      router.push("/plan");
    },
  });
}

export function useRegister() {
  const setAuth = useAuthStore((s) => s.setAuth);
  const router = useRouter();

  return useMutation({
    mutationFn: async (credentials: RegisterCredentials) => {
      await api.post<User>("/auth/register/", credentials);
      try {
        const { data: tokens } = await api.post<AuthTokens>("/auth/token/", {
          username: credentials.username,
          password: credentials.password,
        });
        const { data: user } = await api.get<User>("/auth/me/", {
          headers: { Authorization: `Bearer ${tokens.access}` },
        });
        return { user, tokens, loginFailed: false as const };
      } catch {
        // Account created but auto-login failed — redirect to login
        return { user: null, tokens: null, loginFailed: true as const };
      }
    },
    onSuccess: (result) => {
      if (result.loginFailed) {
        router.push("/login");
      } else {
        setAuth(result.user!, result.tokens!);
        router.push("/plan");
      }
    },
  });
}

export function useLogout() {
  const logout = useAuthStore((s) => s.logout);
  const router = useRouter();
  const queryClient = useQueryClient();

  return () => {
    logout();
    queryClient.clear();
    router.push("/login");
  };
}
