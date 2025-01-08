import { defineConfig } from 'astro/config';

import preact from "@astrojs/preact";

import tailwind from "@astrojs/tailwind";

import remarkMath from 'remark-math';

import rehypeKatex from 'rehype-katex';

import mdx from '@astrojs/mdx';

// https://astro.build/config
export default defineConfig({
  integrations: [preact(), tailwind(), mdx()],
  markdown: {
    remarkPlugins: [remarkMath],
    rehypePlugins: [rehypeKatex],
  },
});