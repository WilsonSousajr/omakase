"use client";

import { GoogleLogin } from "@react-oauth/google";
import { useTranslations } from "next-intl";
import { useState } from "react";

import { useGoogleAuth } from "@/hooks/useAuth";

export default function LoginPage() {
  const t = useTranslations("auth");
  const googleAuth = useGoogleAuth();
  const [error, setError] = useState<string | null>(null);

  return (
    <div className="space-y-6">
      <div className="text-center">
        <h1 className="text-2xl font-semibold text-[var(--color-text-primary)]">
          Omakase
        </h1>
        <p className="mt-1 text-sm text-[var(--color-text-muted)]">
          {t("signIn")}
        </p>
      </div>

      <div className="flex justify-center">
        <GoogleLogin
          onSuccess={(response) => {
            setError(null);
            if (response.credential) {
              googleAuth.mutate(response.credential);
            }
          }}
          onError={() => setError(t("googleSignInFailed"))}
          theme="outline"
          size="large"
          width="320"
        />
      </div>

      {(error || googleAuth.error) && (
        <p className="text-center text-sm text-red-400">
          {error || t("googleSignInFailed")}
        </p>
      )}

      {googleAuth.isPending && (
        <p className="text-center text-sm text-[var(--color-text-muted)]">
          {t("signingIn")}
        </p>
      )}
    </div>
  );
}
