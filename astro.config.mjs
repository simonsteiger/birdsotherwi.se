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
    shikiConfig: {
      themes: {
        light: 'github-light',
        dark: 'github-dark'
      },
    },
    remarkPlugins: [remarkMath],
    rehypePlugins: [rehypeKatex],
  },
  vite: {
    resolve: {
      alias: {
        '@components': '/src/components',
        '@utils': '/src/utils',
        '@layouts': '/src/layouts',
      },
    },
  },
});