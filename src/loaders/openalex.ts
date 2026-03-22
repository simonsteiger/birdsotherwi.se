import type { Loader } from "astro/loaders";
import { nameCorrections } from "../data/nameCorrections";

interface OpenAlexWork {
  id: string;
  title: string | null;
  publication_year: number | null;
  doi: string | null;
  authorships: Array<{
    author: {
      display_name: string | null;
      orcid: string | null;
    };
  }>;
  primary_location: {
    source: {
      display_name: string;
    } | null;
  } | null;
}

interface OpenAlexResponse {
  meta: { count: number };
  results: OpenAlexWork[];
}

export function openAlexLoader({ orcidId }: { orcidId: string }): Loader {
  return {
    name: "openalex-loader",
    load: async ({ store, logger }) => {
      const bareOrcid = orcidId.replace("https://orcid.org/", "");
      const url = `https://api.openalex.org/works?filter=author.orcid:${bareOrcid}&per-page=200&sort=publication_year:desc`;

      let response: Response;
      try {
        response = await fetch(url);
      } catch (err) {
        throw new Error(
          `OpenAlex: network error fetching publications — ${err}`
        );
      }

      if (!response.ok) {
        throw new Error(
          `OpenAlex: API returned ${response.status} ${response.statusText}`
        );
      }

      let data: OpenAlexResponse;
      try {
        data = await response.json();
      } catch (err) {
        throw new Error(`OpenAlex: failed to parse API response as JSON — ${err}`);
      }

      if (!Array.isArray(data.results)) {
        throw new Error(
          "OpenAlex: unexpected response shape — 'results' is not an array"
        );
      }

      store.clear();

      for (const work of data.results) {
        const id = work.id.replace("https://openalex.org/", "");

        store.set({
          id,
          data: {
            title: work.title ?? "Untitled",
            authors: work.authorships.map((a) => ({
              name: nameCorrections[a.author.display_name ?? "Unknown"] ?? a.author.display_name ?? "Unknown",
              orcid: a.author.orcid?.replace("https://orcid.org/", "") ?? null,
            })),
            journal: work.primary_location?.source?.display_name,
            year: work.publication_year ?? new Date().getFullYear(),
            doi: work.doi?.replace("https://doi.org/", ""),
          },
        });
      }

      logger.info(`Loaded ${data.results.length} publications from OpenAlex`);

      if (data.meta.count > data.results.length) {
        logger.warn(
          `OpenAlex: fetched ${data.results.length} of ${data.meta.count} total works — increase per-page limit if publications are missing`
        );
      }
    },
  };
}
