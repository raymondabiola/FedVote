/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#f0edff',
          100: '#ddd6fe',
          200: '#c4b5fd',
          300: '#a78bfa',
          400: '#8b5cf6',
          500: '#6C63FF',
          600: '#5b52e0',
          700: '#4c3fbf',
          800: '#3d329e',
          900: '#2e257d',
          950: '#1a1550',
        },
        surface: {
          50: '#f8f9fc',
          100: '#f1f3f9',
          200: '#e8ecf4',
          300: '#d5dbe8',
        },
      },
      fontFamily: {
        display: ['"DM Sans"', 'system-ui', 'sans-serif'],
        body: ['"DM Sans"', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'monospace'],
      },
    },
  },
  plugins: [],
}
