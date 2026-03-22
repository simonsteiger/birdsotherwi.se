export interface AuthorshipOverride {
  sharedFirst?: boolean;
  sharedLast?: boolean;
}

// Keys are bare DOIs matching the format stored by the loader (e.g. "10.1000/xyz123").
// Set sharedFirst: true if you have equal contribution as first author.
// Set sharedLast: true if you have equal contribution as last author.
export const authorshipOverrides: Record<string, AuthorshipOverride> = {
  "10.1038/s41559-024-02496-4": { sharedFirst: true },
};
