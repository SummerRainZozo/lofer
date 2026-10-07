import { defineConfig } from 'vite';

// On GitHub Pages the site lives under /lofer/ (summerrainzozo.github.io/lofer/),
// so built files need that prefix. The dev server keeps serving from "/".
export default defineConfig(({ command }) => ({
  base: command === 'build' ? '/lofer/' : '/',
}));
