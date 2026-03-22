# Publications Page — Design Spec

**Date:** 2026-03-22
**Status:** Approved

## Overview

Add a `/publications` page to the Astro site at the same level as `/about` and `/posts`. Publications are fetched from OpenAlex at build time using a custom Astro content layer loader, typed via a Zod schema, and rendered as a list of `PublicationCard` components.

## Architecture

Five files are created or modified:

| File | Action |
|---|---|
| `src/loaders/openalex.ts` | New — custom Astro content loader |
| `src/content.config.ts` | Modified — add `publications` collection |
| `src/components/PublicationCard.astro` | New — card component |
| `src/pages/publications.astro` | New — top-level page |
| `src/components/Navigation.astro` | Modified — add Publications link |

## Data Layer

### Source

OpenAlex public API, no authentication required. Single request at build time:

```
GET https://api.openalex.org/works?filter=author.orcid:{orcid-id}&per-page=200&sort=publication_year:desc
```

The ORCID ID is passed as a parameter when registering the loader in `content.config.ts`.

### Loader (`src/loaders/openalex.ts`)

A named export `openAlexLoader({ orcidId })` returns an Astro-compatible `Loader` object with a `load` method. The loader:

1. Fetches the OpenAlex endpoint.
2. Throws on non-OK HTTP status (fails the build with a clear error).
3. Maps each work to a store entry using `store.set({ id, data })`.

### Schema (Zod)

```ts
z.object({
  title: z.string(),
  authors: z.array(z.string()),          // display names
  authorOrcids: z.array(z.string()),     // parallel array of ORCID IDs (empty string if none)
  journal: z.string().optional(),
  year: z.number(),
  doi: z.string().optional(),            // raw DOI, e.g. "10.xxxx/..."
})
```

### Field Mapping

| Schema field | OpenAlex source |
|---|---|
| `title` | `title` |
| `authors` | `authorships[].author.display_name` |
| `authorOrcids` | `authorships[].author.orcid` (strip `https://orcid.org/` prefix, empty string if null) |
| `journal` | `primary_location.source.display_name` |
| `year` | `publication_year` |
| `doi` | `doi` (strip `https://doi.org/` prefix if present) |

## Components

### `PublicationCard.astro`

Props mirror the schema fields plus the user's own ORCID ID for name highlighting:

```ts
interface Props {
  title: string;
  authors: string[];
  authorOrcids: string[];
  userOrcid: string;    // passed from the page, used to bold the user's name
  journal?: string;
  year: number;
  doi?: string;
}
```

Card layout:

```
┌─────────────────────────────────────────────┐
│ Title (anchor linking to DOI if available,   │
│        plain text otherwise)                 │
│ Author One, Author Two, Simon Steiger, ...   │  ← user's name in <strong>
│ Journal Name · 2024                          │  ← journal omitted if absent
└─────────────────────────────────────────────┘
```

Styling follows `PostCard.astro` exactly: bordered box, hover border-color transition, dark mode via `:global(.dark)`.

### `publications.astro`

- Uses `BaseLayout`.
- Calls `getCollection("publications")` — already sorted descending by year from the loader.
- Renders publications in a **single-column** list (not the 2-column grid used for posts, since publication cards are more text-dense).
- Passes the user's ORCID ID as `userOrcid` to each `PublicationCard`.

### `Navigation.astro`

Add `<a href="/publications/">Publications</a>` alongside the existing About and Posts links.

## Error Handling

- Non-OK API response → loader throws → build fails with a descriptive error message.
- Missing `journal` → omit the journal portion of the subtitle line.
- Missing `doi` → render title as plain text instead of a link.
- No retry logic — rerunning the build is sufficient.

## Out of Scope

- Open access badge (deferred).
- Citation counts (deferred).
- Runtime/dynamic data fetching.
- Filtering or searching publications client-side.
