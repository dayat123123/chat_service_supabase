import { ApiError } from '@/lib/errors'

import { parseCsv } from './banned-words'

export type Workbook = { sheet: string; data: (string | Date | null)[][]; widths: number[] }[]

export async function readWordTable(file: File): Promise<unknown[][]> {
  const name = file.name.toLowerCase()
  if (name.endsWith('.csv')) return parseCsv(await file.text())
  if (!name.endsWith('.xlsx')) throw new ApiError('unsupported_file')
  const { readSheet } = await import('read-excel-file/universal')
  try {
    return await readSheet(await file.arrayBuffer())
  } catch {
    throw new ApiError('unreadable_file')
  }
}

export async function saveWorkbook(fileName: string, workbook: Workbook) {
  const { default: writeExcelFile } = await import('write-excel-file/browser')
  await writeExcelFile(
    workbook.map(({ sheet, data, widths }) => ({
      sheet,
      data,
      columns: widths.map((width) => ({ width })),
      dateFormat: 'dd/mm/yyyy',
      stickyRowsCount: 1,
    })),
  ).toFile(fileName)
}
