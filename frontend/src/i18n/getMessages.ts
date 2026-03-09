import type { Locale } from "./config";

export async function getMessages(locale: Locale) {
  switch (locale) {
    case "pt-BR":
      return (await import("../../messages/pt-BR.json")).default;
    default:
      return (await import("../../messages/en.json")).default;
  }
}
