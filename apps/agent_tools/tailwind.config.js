/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#4f46e5',
          light: '#6366f1',
          dark: '#4338ca'
        },
        secondary: {
          DEFAULT: '#10b981',
          light: '#34d399',
          dark: '#059669'
        },
        background: {
          DEFAULT: '#f9fafb',
          dark: '#111827'
        },
        surface: {
          DEFAULT: '#ffffff',
          dark: '#1f2937'
        }
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
        mono: ['Roboto Mono', 'monospace']
      }
    },
  },
  plugins: [],
}
