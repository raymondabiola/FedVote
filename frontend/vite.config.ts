import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    react(),
    {
      name: 'stub-base-org-account',
      resolveId(id) {
        if (id === '@base-org/account') return id;
      },
      load(id) {
        if (id === '@base-org/account') {
          return 'export const createBaseAccountSDK = () => Promise.resolve();';
        }
      },
    },
  ],
  resolve: {
    alias: {
      '@': '/src',
    },
  },
  build: {
    commonjsOptions: {
      transformMixedEsModules: true,
    },
  },
})