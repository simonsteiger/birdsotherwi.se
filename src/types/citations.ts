export interface Citation {
    authors: string[];
    title: string;
    year: number;
    journal: string;
    doi?: string;
    url?: string;
    type: string;
}

export interface CitationMap {
    [key: string]: Citation;
}
