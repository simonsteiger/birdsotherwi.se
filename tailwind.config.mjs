/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{astro,html,js,jsx,md,mdx,svelte,ts,tsx,vue}'],
	theme: {
		extend: {},
		fontFamily: {
			// Your preferred text font. Starlight uses a system font stack by default.
			sans: ['InterVariable'],
			// Your preferred code font. Starlight uses system monospace fonts by default.
			mono: ['JuliaMono-Light', 'monospace'],
		  },
	},
	plugins: [],
}
