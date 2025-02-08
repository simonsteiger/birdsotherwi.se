import { entries } from 'bibtex-parse';
import fs from 'fs/promises';
import type { Citation, CitationMap } from '../types/citations';

export async function loadCitations(path:string): Promise<CitationMap> {
  try {
    const bibContent = await fs.readFile(path, 'utf-8');

    const parsedEntries = entries(bibContent);

    const citations: CitationMap = {};
    parsedEntries.forEach(entry => {
      console.log('Processing entry:', entry.key);
      citations[entry.key] = {
        authors: entry.AUTHOR?.split(' and ') || [],
        title: entry.TITLE?.replace(/[{}]/g, '') || '',
        year: parseInt(entry.YEAR?.toString() || '0'),
        journal: entry.JOURNAL || '',
        doi: entry.DOI,
        url: entry.URL,
        type: entry.type
      };
    });

    return citations;
  } catch (error) {
    console.error('Error loading citations:', error);
    return {};
  }
}