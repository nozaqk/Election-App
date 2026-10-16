import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  plugins: [react(), VitePWA({
    registerType: "autoUpdate",
    // Never cache API traffic: election status must always come from the server.
    workbox: { navigateFallback: "/index.html", runtimeCaching: [{ urlPattern: ({ url }) => url.pathname.startsWith("/student") || url.pathname.startsWith("/auth"), handler: "NetworkOnly" }] },
    manifest: { name: "Student Election", short_name: "Vote", start_url: "/", display: "standalone", background_color: "#0b3d2e", theme_color: "#0b3d2e",
      icons: [
        { src: "/icon-192.png", sizes: "192x192", type: "image/png", purpose: "any" },
        { src: "/icon-512.png", sizes: "512x512", type: "image/png", purpose: "any" },
        { src: "/icon-maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
        { src: "/icon.svg", sizes: "any", type: "image/svg+xml", purpose: "any" },
      ] },
  })],
});
