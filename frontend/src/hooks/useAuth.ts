import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";

import api from "@/lib/api";
import { useAuthStore } from "@/stores/authStore";
import type {
  GoogleAuthResponse,
  UpdateProfilePayload,
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

export function useGoogleAuth() {
  const setAuth = useAuthStore((s) => s.setAuth);
  const router = useRouter();

  return useMutation({
    mutationFn: async (credential: string) => {
      const { data } = await api.post<GoogleAuthResponse>(
        "/auth/google/",
        { credential }
      );
      return data;
    },
    onSuccess: (data) => {
      setAuth(data.user, { access: data.access, refresh: data.refresh });
      router.push("/plan");
    },
  });
}

export function useUpdateProfile() {
  const setUser = useAuthStore((s) => s.setUser);
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (payload: UpdateProfilePayload) => {
      const { data } = await api.patch<User>("/auth/me/", payload);
      return data;
    },
    onSuccess: (user) => {
      setUser(user);
      queryClient.setQueryData(["auth", "me"], user);
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
