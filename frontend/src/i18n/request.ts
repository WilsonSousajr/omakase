import { getRequestConfig } from "next-intl/server";

export default getRequestConfig(async () => ({
  locale: "en",
  timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone,
}));
