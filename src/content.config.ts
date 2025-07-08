import { defineCollection, z } from "astro:content";

import { glob } from "astro/loaders";

const posts = defineCollection({
	loader: glob({ pattern: "*.{md,mdx}", base: "./src/pages/posts" }),
	schema: z.object({
		title: z.string(),
        author: z.string(),
		// slug: z.string(),
		description: z.string(),
		pubDate: z.coerce.date(),
		// updated: z.union([z.string(), z.date()]).optional(),
		tags: z.array(z.string()),
        draft: z.boolean().optional(),
	}),
});

export const collections = { posts };
