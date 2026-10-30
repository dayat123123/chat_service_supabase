import {
  createColumnHelper,
  createSortedRowModel,
  rowSortingFeature,
  sortFn_alphanumeric,
  sortFn_basic,
  tableFeatures,
  type RowData,
} from '@tanstack/react-table'

const columnMeta: { numeric?: boolean } = {}

export const reportTableFeatures = tableFeatures({
  rowSortingFeature,
  sortedRowModel: createSortedRowModel(),
  sortFns: { alphanumeric: sortFn_alphanumeric, basic: sortFn_basic },
  columnMeta,
})

export type ReportTableFeatures = typeof reportTableFeatures

export function reportColumns<T extends RowData>() {
  return createColumnHelper<ReportTableFeatures, T>()
}
