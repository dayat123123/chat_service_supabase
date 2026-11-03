import {
  DownloadIcon,
  FileSpreadsheetIcon,
  LoaderCircleIcon,
  PlusIcon,
  SearchIcon,
  Trash2Icon,
  UploadIcon,
} from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

import { ErrorState, ListSkeleton } from '@/components/states'
import { Button } from '@/components/ui/button'
import {
  RadioGroup,
  RadioGroupItem,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  ToggleGroup,
  ToggleGroupItem,
} from '@/components/ui/controls'
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'
import { Confirm } from '@/features/nasabah/components/confirm'
import { errorText } from '@/lib/error-text'
import { format, formatNumber, isoDay, todayInJakarta } from '@/lib/time'
import { cn } from '@/lib/utils'

import {
  exportSheet,
  IMPORT_MAX_ROWS,
  importPreview,
  normalizeWord,
  wordProblem,
  type ImportPreview,
  type ImportStatus,
} from '../banned-words'
import { readWordTable, saveWorkbook, type Workbook } from '../banned-words-file'
import {
  useAddBannedWord,
  useBannedWords,
  useDeleteBannedWord,
  useImportBannedWords,
  useSetBannedWordAction,
} from '../hooks'
import { DraftBanner } from '../policy-versions/components/draft-banner'
import type { BannedAction, BannedWord, BannedWordList } from '../types'

const bannedActions: BannedAction[] = ['mask', 'block']

const statusTone: Record<ImportStatus, string> = {
  new: 'text-success',
  update: 'text-warning',
  same: 'text-muted-foreground',
  duplicate: 'text-muted-foreground',
  invalid: 'text-destructive',
}

function useActionLabel() {
  const { t } = useTranslation()
  return (action: BannedAction) => t(`compliance.words.actions.${action}`)
}

function ActionCell({ entry }: { entry: BannedWord }) {
  const { t } = useTranslation()
  const label = useActionLabel()
  const change = useSetBannedWordAction()
  return (
    <Select
      value={entry.action}
      disabled={change.isPending}
      onValueChange={(value) =>
        change.mutate(
          { word: entry.word, action: value as BannedAction },
          {
            onSuccess: () =>
              toast.success(
                t('compliance.words.changed', { word: entry.word, action: label(value as BannedAction) }),
              ),
            onError: (error) => toast.error(errorText(error)),
          },
        )
      }
    >
      <SelectTrigger
        className={cn('h-7 w-28', entry.action === 'block' && 'text-destructive')}
        aria-label={t('compliance.words.actionFor', { word: entry.word })}
      >
        <SelectValue />
      </SelectTrigger>
      <SelectContent>
        {bannedActions.map((action) => (
          <SelectItem key={action} value={action}>
            {label(action)}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function ActionChoice({ value, onChange }: { value: BannedAction; onChange: (value: BannedAction) => void }) {
  const { t } = useTranslation()
  const label = useActionLabel()
  return (
    <RadioGroup
      value={value}
      onValueChange={(next) => onChange(next as BannedAction)}
      className="grid gap-2 sm:grid-cols-2"
      aria-label={t('compliance.words.colAction')}
    >
      {bannedActions.map((action) => (
        <label
          key={action}
          className="flex cursor-pointer items-start gap-3 rounded-lg border p-3 has-[[data-state=checked]]:border-primary/50 has-[[data-state=checked]]:bg-primary/5"
        >
          <RadioGroupItem value={action} className="mt-0.5" />
          <span>
            <span className="block text-sm font-medium">{label(action)}</span>
            <span className="block text-xs text-muted-foreground">
              {t(`compliance.words.actionHints.${action}`)}
            </span>
          </span>
        </label>
      ))}
    </RadioGroup>
  )
}

function AddDialog({ open, words, onClose }: { open: boolean; words: BannedWord[]; onClose: () => void }) {
  const { t } = useTranslation()
  const add = useAddBannedWord()
  const [word, setWord] = useState('')
  const [action, setAction] = useState<BannedAction>('mask')
  const [touched, setTouched] = useState(false)
  const normalized = normalizeWord(word)
  const problem = wordProblem(normalized)
  const exists = words.some((entry) => entry.word === normalized)
  const close = () => {
    setWord('')
    setAction('mask')
    setTouched(false)
    onClose()
  }
  return (
    <Dialog open={open} onOpenChange={(next) => !next && !add.isPending && close()}>
      <DialogContent closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('compliance.words.addTitle')}</DialogTitle>
          <DialogDescription>{t('compliance.words.subtitle')}</DialogDescription>
        </DialogHeader>
        <form
          className="flex flex-col gap-4"
          noValidate
          onSubmit={(event) => {
            event.preventDefault()
            setTouched(true)
            if (problem || exists) return
            add.mutate(
              { word: normalized, action },
              {
                onSuccess: () => {
                  toast.success(t('compliance.words.added', { word: normalized }))
                  close()
                },
                onError: (error) => toast.error(errorText(error)),
              },
            )
          }}
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="banned-word">{t('compliance.words.wordLabel')}</Label>
            <Input
              id="banned-word"
              autoFocus
              autoComplete="off"
              maxLength={80}
              value={word}
              aria-invalid={touched && (problem !== null || exists) ? true : undefined}
              onChange={(event) => setWord(event.target.value)}
            />
            {touched && problem ? (
              <p role="alert" className="text-xs text-destructive">
                {t(`compliance.words.problems.${problem}`)}
              </p>
            ) : exists ? (
              <p role="alert" className="text-xs text-destructive">
                {t('compliance.words.exists')}
              </p>
            ) : (
              <p className="text-xs text-muted-foreground">{t('compliance.words.wordHint')}</p>
            )}
          </div>
          <ActionChoice value={action} onChange={setAction} />
          <DialogFooter>
            <Button type="button" variant="ghost" disabled={add.isPending} onClick={close}>
              {t('app.cancel')}
            </Button>
            <Button type="submit" disabled={add.isPending}>
              {add.isPending ? <LoaderCircleIcon className="animate-spin" /> : null}
              {t('compliance.words.add')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function useTemplate(): Workbook {
  const { t } = useTranslation()
  return [
    {
      sheet: t('compliance.words.templateSheet'),
      data: [[t('compliance.words.templateWord'), t('compliance.words.templateAction')]],
      widths: [36, 14],
    },
    {
      sheet: t('compliance.words.guideSheet'),
      data: (['guide1', 'guide2', 'guide3', 'guide4', 'guide5'] as const).map((key) => [
        t(`compliance.words.${key}`),
      ]),
      widths: [110],
    },
  ]
}

function PreviewTable({ preview }: { preview: ImportPreview }) {
  const { t } = useTranslation()
  const label = useActionLabel()
  return (
    <div className="max-h-72 overflow-y-auto rounded-md border">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-16">{t('compliance.words.colLine')}</TableHead>
            <TableHead>{t('compliance.words.colWord')}</TableHead>
            <TableHead className="w-28">{t('compliance.words.colAction')}</TableHead>
            <TableHead>{t('compliance.words.colStatus')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {preview.rows.map((row) => (
            <TableRow key={row.line}>
              <TableCell className="tabular text-xs text-muted-foreground">{row.line}</TableCell>
              <TableCell className="font-medium break-all">{row.word || '–'}</TableCell>
              <TableCell>{row.action ? label(row.action) : '–'}</TableCell>
              <TableCell className={cn('text-row', statusTone[row.status])}>
                {t(`compliance.words.status.${row.status}`)}
                {row.problem ? ` · ${t(`compliance.words.problems.${row.problem}`)}` : null}
                {row.current
                  ? ` · ${t('compliance.words.updateFrom', { action: label(row.current) })}`
                  : null}
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    </div>
  )
}

function ImportDialog({ open, list, onClose }: { open: boolean; list: BannedWordList; onClose: () => void }) {
  const { t } = useTranslation()
  const run = useImportBannedWords()
  const template = useTemplate()
  const input = useRef<HTMLInputElement>(null)
  const [fileName, setFileName] = useState<string | null>(null)
  const [preview, setPreview] = useState<ImportPreview | null>(null)
  const [reading, setReading] = useState(false)
  const [failure, setFailure] = useState<unknown>(null)
  const close = () => {
    setFileName(null)
    setPreview(null)
    setFailure(null)
    onClose()
  }
  const choose = async (file: File | undefined) => {
    if (!file) return
    setReading(true)
    setFailure(null)
    try {
      setPreview(importPreview(await readWordTable(file), list.words, list.limit))
      setFileName(file.name)
    } catch (error) {
      setPreview(null)
      setFailure(error)
    } finally {
      setReading(false)
      if (input.current) input.current.value = ''
    }
  }
  const blocked = !preview || preview.tooMany || preview.overLimit || preview.payload.length === 0
  return (
    <Dialog open={open} onOpenChange={(next) => !next && !run.isPending && close()}>
      <DialogContent className="sm:max-w-3xl" closeLabel={t('app.close')}>
        <DialogHeader>
          <DialogTitle>{t('compliance.words.importTitle')}</DialogTitle>
          <DialogDescription>
            {t('compliance.words.importHint', { max: formatNumber(IMPORT_MAX_ROWS) })}
          </DialogDescription>
        </DialogHeader>
        <div className="flex flex-wrap items-center gap-2">
          <input
            ref={input}
            type="file"
            accept=".xlsx,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv"
            className="sr-only"
            aria-label={t('compliance.words.chooseFile')}
            onChange={(event) => void choose(event.target.files?.[0])}
          />
          <Button
            variant="outline"
            disabled={reading || run.isPending}
            onClick={() => input.current?.click()}
          >
            {reading ? <LoaderCircleIcon className="animate-spin" /> : <FileSpreadsheetIcon />}
            {preview ? t('compliance.words.chooseAnother') : t('compliance.words.chooseFile')}
          </Button>
          <Button
            variant="ghost"
            onClick={() =>
              void saveWorkbook('template-kata-terlarang.xlsx', template).catch((error: unknown) =>
                toast.error(errorText(error)),
              )
            }
          >
            <DownloadIcon />
            {t('compliance.words.template')}
          </Button>
          {fileName ? (
            <span className="min-w-0 truncate text-xs text-muted-foreground">
              {t('compliance.words.fileLabel', { name: fileName })}
            </span>
          ) : null}
        </div>
        {failure ? (
          <p role="alert" className="text-row text-destructive">
            {errorText(failure)}
          </p>
        ) : null}
        {preview ? (
          <div className="flex min-h-0 flex-col gap-3">
            <p role="status" className="flex flex-wrap gap-x-4 gap-y-1 text-row">
              {(['new', 'update', 'same', 'duplicate', 'invalid'] as const).map((status) => (
                <span key={status} className={statusTone[status]}>
                  {t(`compliance.words.status.${status}`)}{' '}
                  <span className="tabular font-medium">{formatNumber(preview.counts[status])}</span>
                </span>
              ))}
            </p>
            {preview.tooMany ? (
              <p role="alert" className="text-row text-destructive">
                {t('compliance.words.tooMany', { max: formatNumber(IMPORT_MAX_ROWS) })}
              </p>
            ) : preview.overLimit ? (
              <p role="alert" className="text-row text-destructive">
                {t('compliance.words.overLimit', { limit: formatNumber(list.limit) })}
              </p>
            ) : preview.payload.length === 0 ? (
              <p className="text-row text-muted-foreground">{t('compliance.words.nothing')}</p>
            ) : null}
            {preview.rows.length > 0 ? <PreviewTable preview={preview} /> : null}
          </div>
        ) : null}
        <DialogFooter>
          <Button type="button" variant="ghost" disabled={run.isPending} onClick={close}>
            {t('app.cancel')}
          </Button>
          <Button
            disabled={blocked || run.isPending}
            onClick={() =>
              preview &&
              run.mutate(preview.payload, {
                onSuccess: (result) => {
                  toast.success(
                    t('compliance.words.imported', { added: result.added, updated: result.updated }),
                  )
                  close()
                },
                onError: (error) => toast.error(errorText(error)),
              })
            }
          >
            {run.isPending ? <LoaderCircleIcon className="animate-spin" /> : <UploadIcon />}
            {t('compliance.words.importAction', { count: preview?.payload.length ?? 0 })}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

function WordsTable({ words, onDelete }: { words: BannedWord[]; onDelete: (entry: BannedWord) => void }) {
  const { t } = useTranslation()
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{t('compliance.words.colWord')}</TableHead>
          <TableHead className="w-36">{t('compliance.words.colAction')}</TableHead>
          <TableHead className="w-36">{t('compliance.words.colAdded')}</TableHead>
          <TableHead className="w-12">
            <span className="sr-only">{t('compliance.words.colDelete')}</span>
          </TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {words.map((entry) => (
          <TableRow key={entry.word}>
            <TableCell className="font-medium break-all">{entry.word}</TableCell>
            <TableCell>
              <ActionCell entry={entry} />
            </TableCell>
            <TableCell className="tabular text-xs text-muted-foreground">
              {format(entry.created_at, 'd MMM yyyy')}
            </TableCell>
            <TableCell>
              <Button
                variant="ghost"
                size="icon-xs"
                aria-label={t('compliance.words.deleteLabel', { word: entry.word })}
                onClick={() => onDelete(entry)}
              >
                <Trash2Icon />
              </Button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}

export function BannedWordsPage() {
  const { t } = useTranslation()
  const label = useActionLabel()
  const list = useBannedWords()
  const remove = useDeleteBannedWord()
  const [query, setQuery] = useState('')
  const [filter, setFilter] = useState<'all' | BannedAction>('all')
  const [adding, setAdding] = useState(false)
  const [importing, setImporting] = useState(false)
  const [removing, setRemoving] = useState<BannedWord | null>(null)
  const [exporting, setExporting] = useState(false)
  const words = list.data?.words ?? []
  const needle = normalizeWord(query)
  const shown = words.filter(
    (entry) =>
      (filter === 'all' || entry.action === filter) && (needle === '' || entry.word.includes(needle)),
  )
  const full = list.data ? words.length >= list.data.limit : false

  const download = async () => {
    setExporting(true)
    try {
      await saveWorkbook(`kata-terlarang-${isoDay(todayInJakarta())}.xlsx`, [
        { sheet: t('compliance.words.templateSheet'), data: exportSheet(words, label), widths: [36, 14, 14] },
      ])
    } catch (error) {
      toast.error(errorText(error))
    } finally {
      setExporting(false)
    }
  }

  return (
    <div className="h-full overflow-y-auto">
      <div className="mx-auto flex max-w-[1120px] flex-col gap-4 px-4 py-5 lg:px-6">
        <header className="flex flex-wrap items-end justify-between gap-3">
          <div className="max-w-2xl min-w-0">
            <h1 className="text-lg font-semibold">{t('compliance.words.title')}</h1>
            <p className="text-row text-muted-foreground">{t('compliance.words.subtitle')}</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              size="sm"
              variant="outline"
              disabled={exporting || words.length === 0}
              onClick={() => void download()}
            >
              {exporting ? <LoaderCircleIcon className="animate-spin" /> : <DownloadIcon />}
              {t('compliance.words.export')}
            </Button>
            <Button size="sm" variant="outline" disabled={!list.data} onClick={() => setImporting(true)}>
              <UploadIcon />
              {t('compliance.words.import')}
            </Button>
            <Button size="sm" disabled={!list.data || full} onClick={() => setAdding(true)}>
              <PlusIcon />
              {t('compliance.words.add')}
            </Button>
          </div>
        </header>
        <DraftBanner />
        <div className="flex flex-wrap items-center gap-2">
          <ToggleGroup
            type="single"
            value={filter}
            onValueChange={(value) => value && setFilter(value as 'all' | BannedAction)}
            aria-label={t('compliance.words.filterLabel')}
          >
            <ToggleGroupItem value="all">{t('compliance.words.filterAll')}</ToggleGroupItem>
            {bannedActions.map((action) => (
              <ToggleGroupItem key={action} value={action}>
                {label(action)}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
          <div className="relative w-full sm:w-72">
            <SearchIcon className="pointer-events-none absolute top-2 left-2.5 size-4 text-muted-foreground" />
            <Input
              type="search"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={t('compliance.words.search')}
              aria-label={t('compliance.words.search')}
              className="h-8 pl-8"
            />
          </div>
          {list.data ? (
            <span className={cn('tabular ml-auto text-xs', full ? 'text-warning' : 'text-muted-foreground')}>
              {t('compliance.words.count', {
                count: words.length,
                total: formatNumber(words.length),
                limit: formatNumber(list.data.limit),
              })}
            </span>
          ) : null}
        </div>
        {list.data ? (
          shown.length > 0 ? (
            <WordsTable words={shown} onDelete={setRemoving} />
          ) : (
            <p className="border-y py-6 text-center text-row text-muted-foreground">
              {words.length === 0 ? t('compliance.words.empty') : t('compliance.words.noMatch')}
            </p>
          )
        ) : list.isError ? (
          <ErrorState error={list.error} onRetry={() => void list.refetch()} />
        ) : (
          <ListSkeleton rows={6} />
        )}
      </div>
      <AddDialog open={adding} words={words} onClose={() => setAdding(false)} />
      {list.data ? (
        <ImportDialog open={importing} list={list.data} onClose={() => setImporting(false)} />
      ) : null}
      <Confirm
        open={removing !== null}
        title={t('compliance.words.deleteTitle', { word: removing?.word ?? '' })}
        body={t('compliance.words.deleteBody')}
        action={t('compliance.words.delete')}
        pending={remove.isPending}
        destructive
        onConfirm={() =>
          removing &&
          remove.mutate(removing.word, {
            onSuccess: () => {
              toast.success(t('compliance.words.deleted', { word: removing.word }))
              setRemoving(null)
            },
            onError: (error) => toast.error(errorText(error)),
          })
        }
        onClose={() => setRemoving(null)}
      />
    </div>
  )
}
