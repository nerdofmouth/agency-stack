/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/app/**/*.{js,ts,jsx,tsx}",
    "./src/pages/**/*.{js,ts,jsx,tsx}",
    "./src/components/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'agency': {
          50: '#f5f7fa',
          100: '#e4ebf2',
          200: '#d0dde9',
          300: '#b1c7d9',
          400: '#8aa8c5',
          500: '#6d8eb2',
          600: '#5c7ca1',
          700: '#4d678a',
          800: '#425673',
          900: '#384860',
          950: '#25303f',
        },
      },
    },
  },
  plugins: [],
}
