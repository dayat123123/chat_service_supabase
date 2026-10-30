function normalize(text: string) {
  return text.normalize('NFKD').replace(/\p{M}/gu, '').toLocaleLowerCase('id')
}

export function matchesQuery(text: string, query: string) {
  const haystack = normalize(text)
  return normalize(query)
    .split(/\s+/)
    .filter(Boolean)
    .every((word) => haystack.includes(word))
}
