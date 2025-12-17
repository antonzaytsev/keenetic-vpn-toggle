import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

const port = parseInt(process.env.VITE_PORT || '3000', 10)

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port
  },
  preview: {
    host: '0.0.0.0',
    port
  }
})

