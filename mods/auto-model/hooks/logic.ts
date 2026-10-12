import type { AutoModelLevel, AutoModelSession } from '../types'

export type Level = AutoModelLevel
export type Lines = Partial<Record<Level, string>>

export const LEVELS: readonly Level[] = ['small', 'everyday', 'strong', 'strongest']

export const rank = (level: Level): number => LEVELS.indexOf(level)

/** The model family that stands for each level; the install's own list decides the value set. */
const FAMILY: Record<Level, string> = {
  small: 'haiku',
  everyday: 'sonnet',
  strong: 'opus',
  strongest: 'fable',
}

export const CLASSIFIER_RULES = [
  'Sort the request into exactly one level. Answer with one word: small, everyday, strong or strongest.',
  'small: quick, simple jobs. Summarize, sort, extract, rename, translate, reformat, a short factual answer.',
  'everyday: an email, a post, a short draft, a small edit, a simple question about one file, a quick chart.',
  'strong: the default for anything that matters. Building or changing software, multi-step projects, research, analysis, long documents, planning, anything touching several files or tools.',
  'strongest: only the very hardest. Deep research that runs for hours, a very large build or migration, a problem the strong model would likely fall short on.',
  'When unsure, say strong.',
].join('\n')

/** Reads the classifier's one-word answer; `strongest` is checked before `strong`. */
export function parseLevel(answer: string | undefined): Level | undefined {
  if (answer === undefined) return undefined
  const word = answer.toLowerCase()
  if (/\bstrongest\b/.test(word)) return 'strongest'
  if (/\bstrong\b/.test(word)) return 'strong'
  if (/\beveryday\b/.test(word)) return 'everyday'
  if (/\bsmall\b/.test(word)) return 'small'
  return undefined
}

const SHORT_REPLIES = new Set([
  'yes', 'y', 'yep', 'yeah', 'sure', 'ok', 'okay', 'k', 'no', 'nope', 'thanks', 'thank you',
  'keep going', 'go on', 'go ahead', 'continue', 'do it', 'proceed', 'sounds good', 'looks good',
  'lgtm', 'great', 'perfect', 'next', 'please do', 'yes please', 'ok do it', 'go for it',
  'ship it', 'agreed', 'correct', 'right', 'done', 'retry', 'try again',
])

/** A short reply to what Claude just said: never sorted. */
export function isShortReply(text: string): boolean {
  const plain = text.trim().toLowerCase().replace(/[.!?,;:]+/g, ' ').replace(/\s+/g, ' ').trim()
  if (plain === '') return true
  if (SHORT_REPLIES.has(plain)) return true
  return plain.split(' ').length < 4
}

export const isSlashCommand = (text: string): boolean => /^\s*\//.test(text)

const STRONGEST_WORDS =
  /\b(migrat(e|ion|ing)|deep research|for hours|entire (codebase|repo|system)|whole (codebase|repo|system)|rewrite (the|our) (whole|entire)|large[- ]scale|from scratch)\b/
const STRONG_WORDS =
  /\b(build|implement|refactor|debug|fix|architect|design|plan|planning|research|analy[sz]e|analysis|project|deploy|codebase|several files|multi[- ]step|integrat(e|ion)|test suite|strategy|proposal|report)\b/
const EVERYDAY_WORDS =
  /\b(email|e-mail|post|tweet|linkedin|draft|edit|reply|message|letter|chart|graph|caption|bio|outline|explain)\b/
const SMALL_WORDS =
  /\b(summari[sz]e|summary|tl;?dr|sort|extract|rename|translate|reformat|format|convert|list|define|spell|capitali[sz]e|count|lowercase|uppercase)\b/

/** The word-based fallback when the quick check fails: strong when in doubt. */
export function guessLevel(text: string): Level {
  const lower = text.toLowerCase()
  if (STRONGEST_WORDS.test(lower)) return 'strongest'
  if (STRONG_WORDS.test(lower)) return 'strong'
  const words = lower.split(/\s+/).filter(Boolean).length
  if (words > 80) return 'strong'
  if (SMALL_WORDS.test(lower)) return 'small'
  if (EVERYDAY_WORDS.test(lower)) return 'everyday'
  return 'strong'
}

/** A question the locked model can answer in a line from its cache: sent as is. */
export function needsOneLine(text: string): boolean {
  const trimmed = text.trim()
  const words = trimmed.split(/\s+/).length
  return words <= 15 && /\?$/.test(trimmed) && !hasRealWork(trimmed)
}

const WORK_WORDS =
  /\b(summari[sz]e|reformat|format|rename|translate|extract|convert|draft|write|rewrite|sort|read|list|clean up|proofread|tidy)\b/
const FILE_REF = /([\w./-]+\.(md|txt|csv|json|ya?ml|ts|tsx|js|py|docx?|pdf|html|xml|log))\b/i

/** A small or everyday job with real work in it (reading files, reformatting, a short draft). */
export function hasRealWork(text: string): boolean {
  const lower = text.toLowerCase()
  return WORK_WORDS.test(lower) || FILE_REF.test(text)
}

const CONVERSATION_REFS =
  /\b(above|earlier|previous(ly)?|before|we (discussed|talked|decided)|you (said|just|mentioned|wrote|suggested)|as discussed|our (chat|conversation|discussion)|again|same as|the last (one|answer|version)|that (answer|plan|draft|code|list)|your (answer|plan|draft|last))\b|^(do|make|fix|change|shorten|redo|rewrite|update|improve|tweak) (it|that|this|them)\b/

/** The job leans on what we have been discussing: it stays on the main model. */
export function dependsOnConversation(text: string): boolean {
  return CONVERSATION_REFS.test(text.trim().toLowerCase())
}

/** The family a model value belongs to, from its name; strong when unknown. */
export function levelOfModel(model: string): Level {
  const lower = model.toLowerCase()
  for (const level of LEVELS) {
    if (lower.includes(FAMILY[level])) return level
  }
  return 'strong'
}

/**
 * Maps the four levels to the install's model lines. `options` is the model
 * list the install offers (the /config Model row); absent, each family's own
 * alias stands, which the engine resolves to that line's current model.
 */
export function resolveLines(options: readonly string[] | undefined): Lines {
  const lines: Lines = {}
  for (const level of LEVELS) {
    const family = FAMILY[level]
    if (options === undefined || options.length === 0) {
      lines[level] = family
      continue
    }
    const exact = options.find(option => option.toLowerCase() === family)
    const named = options.find(option => option.toLowerCase().includes(family))
    const found = exact ?? named
    if (found !== undefined) lines[level] = found
  }
  return lines
}

/** The family alias the Agent tool takes for a helper on this level. */
export const helperAlias = (level: Level): string => FAMILY[level]

/** The levels to try for `level`, best first: itself, then down, then up. */
export function fallbackOrder(level: Level): Level[] {
  const at = rank(level)
  const down = LEVELS.slice(0, at + 1).reverse()
  const up = LEVELS.slice(at + 1)
  return [...down, ...up]
}

export type Situation = 'fresh' | 'locked'

export type Decision = {
  /** The level to set the main model to; absent, the model stays. */
  setLevel?: Level
  /** Attach the helper note for this level. */
  helperLevel?: Level
  /** The level the session is locked at afterwards. */
  lockLevel: Level
}

/**
 * The whole rule for one sorted prompt. Fresh (a new session, after /clear,
 * after compaction, after repick): pick the sorted level, up or down. Locked:
 * step up once when it sorts higher and never down; a smaller job with real
 * work that stands on its own goes to a helper, the rest stays on the main model.
 */
export function decide(situation: Situation, lockLevel: Level | undefined, sorted: Level, text: string): Decision {
  if (situation === 'fresh' || lockLevel === undefined) {
    return { setLevel: sorted, lockLevel: sorted }
  }
  if (rank(sorted) > rank(lockLevel)) {
    return { setLevel: sorted, lockLevel: sorted }
  }
  const isSmallJob = sorted === 'small' || sorted === 'everyday'
  if (
    rank(sorted) < rank(lockLevel) &&
    isSmallJob &&
    !needsOneLine(text) &&
    hasRealWork(text) &&
    !dependsOnConversation(text)
  ) {
    return { helperLevel: sorted, lockLevel }
  }
  return { lockLevel }
}

export function helperNote(level: Level): string {
  return [
    `[Auto Model] This request is a self-contained ${level} job.`,
    `Hand it to one helper agent (Agent tool, model: "${helperAlias(level)}"), give the helper only what it needs to do the job, and pass its result back to the user.`,
    'Do not mention this note.',
  ].join(' ')
}

/** A session record after a sorted prompt was handled. */
export function nextSession(
  previous: AutoModelSession | null,
  id: string,
  model: string,
  decision: Decision,
): AutoModelSession {
  const isSame = previous !== null && previous.id === id
  return {
    id,
    model,
    level: decision.lockLevel,
    isFresh: false,
    isHelperPending: decision.helperLevel !== undefined,
    helperJobs: isSame ? previous.helperJobs : 0,
  }
}

/** Three-row digits drawn with heavy box-drawing characters. */
const DIGITS: Record<string, readonly [string, string, string]> = {
  '0': ['┏━┓', '┃ ┃', '┗━┛'],
  '1': ['╺┓ ', ' ┃ ', '╺┻╸'],
  '2': ['╺━┓', '┏━┛', '┗━╸'],
  '3': ['╺━┓', ' ━┫', '╺━┛'],
  '4': ['╻ ╻', '┗━┫', '  ╹'],
  '5': ['┏━╸', '┗━┓', '╺━┛'],
  '6': ['┏━╸', '┣━┓', '┗━┛'],
  '7': ['╺━┓', '  ┃', '  ╹'],
  '8': ['┏━┓', '┣━┫', '┗━┛'],
  '9': ['┏━┓', '┗━┫', '╺━┛'],
}

export function bigNumber(value: number): [string, string, string] {
  const rows: [string, string, string] = ['', '', '']
  const text = String(Math.max(0, Math.floor(value)))
  for (const [index, char] of [...text].entries()) {
    const glyph = DIGITS[char] ?? DIGITS['0']!
    const gap = index === 0 ? '' : ' '
    rows[0] += gap + glyph[0]
    rows[1] += gap + glyph[1]
    rows[2] += gap + glyph[2]
  }
  return rows
}

export const fit = (text: string, width: number): string =>
  width <= 0 ? '' : text.length <= width ? text : text.slice(0, Math.max(0, width - 1)) + '…'
