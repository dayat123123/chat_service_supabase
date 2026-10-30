const verbose = import.meta.env.DEV

export const logger = {
  warn(message: string, detail?: unknown) {
    if (verbose) console.warn(message, detail)
    else console.warn(message)
  },
  error(message: string, detail?: unknown) {
    if (verbose) console.error(message, detail)
    else console.error(message)
  },
}
