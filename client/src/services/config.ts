type RuntimeConfig = {
  API_URL?: string;
};

type WindowWithConfig = Window & {
  __CONFIG__?: RuntimeConfig;
};

export type AppConfig = {
  API_URL: string;
};

export function getConfig(): AppConfig {
  const runtimeConfig = (window as WindowWithConfig).__CONFIG__;
  const runtimeApiUrl = runtimeConfig?.API_URL;
  const env = (import.meta as ImportMeta).env;
  const envApiUrl = env.VITE_API_URL;

  const apiUrl =
    typeof runtimeApiUrl === "string" && runtimeApiUrl.trim().length > 0
      ? runtimeApiUrl.trim()
      : typeof envApiUrl === "string" && envApiUrl.trim().length > 0
        ? envApiUrl.trim()
        : "";

  return { API_URL: apiUrl };
}
