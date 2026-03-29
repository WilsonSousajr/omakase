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
    <div className="flex flex-col items-center">
      {/* Brand */}
      <div
        className="mb-12 flex flex-col items-center"
        style={{ animation: "fade-in-up 0.6s ease-out both" }}
      >
        <h1 className="text-2xl font-light uppercase tracking-[0.3em] text-[var(--color-text-primary)]">
          Omakase
        </h1>
        <div className="mt-4 h-px w-8 bg-[var(--color-border)]" />
        <p className="mt-4 text-xs text-[var(--color-text-faint)]">
          {t("tagline")}
        </p>
      </div>

      {/* Sign-in */}
      <div
        className="flex flex-col items-center space-y-4"
        style={{ animation: "fade-in-up 0.6s ease-out 0.15s both" }}
      >
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
    </div>
  );
}
