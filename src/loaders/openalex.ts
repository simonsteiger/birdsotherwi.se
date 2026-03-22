import type { Loader } from "astro/loaders";

interface OpenAlexWork {
  id: string;
  title: string;
  publication_year: number;
  doi: string | null;
  authorships: Array<{
    author: {
      display_name: string;
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
  results: OpenAlexWork[];
}

export function openAlexLoader({ orcidId }: { orcidId: string }): Loader {
  return {
    name: "openalex-loader",
    load: async ({ store, logger }) => {
      const url = `https://api.openalex.org/works?filter=author.orcid:${orcidId}&per-page=200&sort=publication_year:desc`;

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

      const data: OpenAlexResponse = await response.json();

      store.clear();

      for (const work of data.results) {
        const id = work.id.replace("https://openalex.org/", "");

        store.set({
          id,
          data: {
            title: work.title,
            authors: work.authorships.map((a) => a.author.display_name),
            authorOrcids: work.authorships.map(
              (a) => a.author.orcid?.replace("https://orcid.org/", "") ?? ""
            ),
            journal:
              work.primary_location?.source?.display_name ?? undefined,
            year: work.publication_year,
            doi: work.doi?.replace("https://doi.org/", "") ?? undefined,
          },
        });
      }

      logger.info(`Loaded ${data.results.length} publications from OpenAlex`);
    },
  };
}
