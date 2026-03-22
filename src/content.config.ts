import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";
import { openAlexLoader } from "./loaders/openalex";
import { AUTHOR_ORCID } from "./config";

const posts = defineCollection({
  loader: glob({ pattern: "*.{md,mdx}", base: "./src/pages/posts" }),
  schema: z.object({
    title: z.string(),
    author: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    tags: z.array(z.string()),
    draft: z.boolean().optional(),
  }),
});

const publications = defineCollection({
  loader: openAlexLoader({ orcidId: AUTHOR_ORCID }),
  schema: z.object({
    title: z.string(),
    authors: z.array(
      z.object({
        name: z.string(),
        orcid: z.string().nullable(),
      })
    ),
    journal: z.string().optional(),
    year: z.number(),
    doi: z.string().optional(),
  }),
});

export const collections = { posts, publications };
