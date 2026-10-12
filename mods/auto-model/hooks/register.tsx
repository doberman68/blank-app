import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { AutoModelSession } from '../types'
import {
  CLASSIFIER_RULES,
  bigNumber,
  decide,
  fallbackOrder,
  fit,
  guessLevel,
  helperAlias,
  helperNote,
  isShortReply,
  isSlashCommand,
  levelOfModel,
  nextSession,
  parseLevel,
  resolveLines,
} from './logic'
import type { Level, Lines } from './logic'

const isOn = atom({ plugin: 'auto-model', key: 'isOn' } as const, false)
const session = atom({ plugin: 'auto-model', key: 'session' } as const, null)

const STORE_ON = 'isOn'
const STORE_BEFORE = 'modelBeforeOn'
const STORE_RESTORE = 'restoreModelNextSession'

const GOLD = '#F2C46D'
const HAIRLINE = '#262B33'
const MUTED = '#7D8590'
const TEXT = '#E6EDF3'
const GOOD = '#3DD68C'
const WARN = '#E3B341'
const INK = '#0D1117'

type Engine = EngineInterface

/** The /config row that holds the main model, when the install has one. */
async function modelRow($: Engine) {
  const rows = await $.config.list()
  return rows.find(row => row.key === 'model') ?? rows.find(row => /^model$/i.test(row.label))
}

async function installLines($: Engine): Promise<Lines> {
  const row = await modelRow($)
  return resolveLines(row?.kind === 'choice' ? row.options : undefined)
}

// Our own model change, so the manual-pick watch does not mistake it for the person's.
let selfSwitchUntil = 0

async function showStatus($: Engine) {
  const enabled = await read($, isOn)
  if (!enabled) {
    $.ui.status(undefined)
    return
  }
  $.ui.status(`Auto · ${await $.session.model()}`)
}

/** Sets the main model to the first level that works, from `level` down. */
async function setMainModel($: Engine, level: Level): Promise<{ level: Level; model: string } | undefined> {
  const row = await modelRow($)
  if (row === undefined || row.isLocked) return undefined
  const lines = resolveLines(row.kind === 'choice' ? row.options : undefined)
  for (const candidate of fallbackOrder(level)) {
    const value = lines[candidate]
    if (value === undefined) continue
    selfSwitchUntil = (await $.clock.now()) + 5000
    const result = await $.config.set({ key: row.key, value })
    if (result.deny === undefined) return { level: candidate, model: value }
  }
  return undefined
}

/** Asks the smallest model for the level; the word fallback on any failure. */
async function sortPrompt($: Engine, text: string): Promise<Level> {
  try {
    const lines = await installLines($)
    const result = await $.model.complete({
      model: lines.small ?? 'haiku',
      system: CLASSIFIER_RULES,
      prompt: `Request:\n${text.slice(0, 6000)}\n\nLevel:`,
      maxTokens: 8,
      timeoutMs: 4000,
    })
    if (result.isAnswered) return parseLevel(result.text) ?? guessLevel(text)
  } catch {
    // fall through to the word guess
  }
  return guessLevel(text)
}

async function turnOn($: Engine) {
  await $.store.set(STORE_BEFORE, await $.session.model())
  await $.store.set(STORE_ON, true)
  await $.store.delete(STORE_RESTORE)
  await update($, isOn, () => true)
  await showStatus($)
}

/** Off: the current model stays for this session; the next new session goes back. */
async function turnOff($: Engine, options: { isManualPick: boolean }) {
  const before = await $.store.get(STORE_BEFORE)
  await $.store.set(STORE_ON, false)
  if (!options.isManualPick && typeof before === 'string') await $.store.set(STORE_RESTORE, before)
  else await $.store.delete(STORE_RESTORE)
  await update($, isOn, () => false)
  await showStatus($)
}

function markRepick($: Engine) {
  return update($, session, current => (current === null ? current : { ...current, isFresh: true }))
}

async function statusText($: Engine) {
  const enabled = await read($, isOn)
  const current = await read($, session)
  const id = await $.session.id()
  const live = current !== null && current.id === id ? current : null
  const model = live?.model ?? (await $.session.model())
  return [
    `Auto Model: ${enabled ? 'On' : 'Off'}`,
    `Locked model: ${live === null ? `none yet (running ${model})` : model}`,
    `Chosen at level: ${live?.level ?? 'not sorted yet'}`,
    `Jobs sent to helpers this session: ${live?.helperJobs ?? 0}`,
  ].join('\n')
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    try {
      await $.command.register({
        name: 'automodel',
        description: 'Auto Model: on, off, status, or repick the next prompt',
        argumentHint: 'on|off|status|repick',
      })
      const stored = (await $.store.get(STORE_ON)) === true
      await update($, isOn, () => stored)
      const restore = await $.store.get(STORE_RESTORE)
      if (!stored && typeof restore === 'string') {
        const row = await modelRow($)
        if (row !== undefined && !row.isLocked) {
          selfSwitchUntil = (await $.clock.now()) + 5000
          await $.config.set({ key: row.key, value: restore })
        }
        await $.store.delete(STORE_RESTORE)
      }
      await showStatus($)
    } catch {
      // the session starts either way
    }
    return next(e)
  })

  // Compaction and /clear empty the cache: the next typed prompt picks fresh.
  on('classic.PostCompact', async ($, e, next) => {
    await markRepick($)
    return next(e)
  }).catch(($, e, next) => next(e))

  on('session.end', { reason: 'clear' }, async ($, e, next) => {
    await update($, session, () => null)
    return next(e)
  })

  on('prompt.submit', async ($, e, next) => {
    if (!(await read($, isOn))) return next(e)
    const isTyped = e.origin.kind === 'composer' || e.origin.kind === 'bridge'
    if (!isTyped || e.turnId !== undefined || isSlashCommand(e.text)) return next(e)

    const id = await $.session.id()
    let current: AutoModelSession | null = await read($, session)
    if (current !== null && current.id !== id) current = null

    let situation: 'fresh' | 'locked' = 'locked'
    if (current === null) {
      const messages = await $.session.messages()
      const isUnderway = messages.some(message => message.role === 'assistant')
      if (isUnderway) {
        // A resumed session keeps the model it had.
        const model = await $.session.model()
        current = { id, model, level: levelOfModel(model), isFresh: false, isHelperPending: false, helperJobs: 0 }
      } else {
        situation = 'fresh'
      }
    } else if (current.isFresh) {
      situation = 'fresh'
    }

    if (situation === 'locked' && isShortReply(e.text)) {
      await update($, session, () => current)
      return next(e)
    }

    const sorted = await sortPrompt($, e.text)
    const decision = decide(situation, current?.level, sorted, e.text)
    let model = current?.model ?? (await $.session.model())
    let lockLevel = decision.lockLevel
    if (decision.setLevel !== undefined) {
      const set = await setMainModel($, decision.setLevel)
      if (set !== undefined) {
        model = set.model
        lockLevel = set.level
      } else {
        lockLevel = current?.level ?? levelOfModel(model)
      }
    }
    await update($, session, previous =>
      nextSession(previous !== null && previous.id === id ? previous : current, id, model, { ...decision, lockLevel }),
    )
    await showStatus($)

    if (decision.helperLevel !== undefined) {
      return next({ ...e, context: [...(e.context ?? []), helperNote(decision.helperLevel)] })
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  // Counts the jobs the main model actually handed to a helper after a note.
  on('tool.call', { tool: 'Agent' }, async ($, e, next) => {
    const current = await read($, session)
    if (current !== null && current.isHelperPending && e.agentId === undefined) {
      const model = String((e as { model?: unknown }).model ?? '')
      if (model === helperAlias('small') || model === helperAlias('everyday')) {
        await update($, session, value =>
          value === null ? value : { ...value, isHelperPending: false, helperJobs: value.helperJobs + 1 },
        )
      }
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const current = await read($, session)
    if (current !== null && current.isHelperPending && e.agentId === undefined) {
      await update($, session, value => (value === null ? value : { ...value, isHelperPending: false }))
    }
    return next(e)
  })

  // A model picked by hand while Auto Model is on turns Auto Model off.
  on('classic.PostModelSwitch', async ($, e, next) => {
    const isOurs = (await $.clock.now()) < selfSwitchUntil
    if (!isOurs && (e.source === 'command' || e.source === 'picker') && (await read($, isOn))) {
      await turnOff($, { isManualPick: true })
    } else {
      await showStatus($)
    }
    return next(e)
  }).catch(($, e, next) => next(e))

  on('command.run', { command: 'automodel' }, async ($, e) => {
    try {
      const arg = e.args.trim().toLowerCase()
      if (arg === 'on') {
        await turnOn($)
        return { text: 'Auto Model is on. Your next prompt sets the model for this session.' }
      }
      if (arg === 'off') {
        await turnOff($, { isManualPick: false })
        return { text: 'Auto Model is off. The current model stays for this session; your next session starts on the model you used before.' }
      }
      if (arg === 'repick') {
        if (!(await read($, isOn))) return { text: 'Auto Model is off. Turn it on with /automodel on first.' }
        await markRepick($)
        return { text: 'Your next prompt will be sorted fresh and may move the model up or down. This rebuilds the cache once.' }
      }
      if (arg === '' || arg === 'status') return { text: await statusText($) }
      return { text: 'Use /automodel on, off, status or repick.' }
    } catch (error) {
      return { text: `Auto Model could not do that: ${error instanceof Error ? error.message : String(error)}` }
    }
  }).catch(() => ({ text: 'Auto Model could not do that. Try again, or run /automodel status.' }))

  // The status-bar switch, beside the footer's mode labels.
  on('ui.render', { component: 'SessionMode' }, async ($, e) => {
    const { Box, Button, Text } = $.ui.resolve(e)
    const enabled = await read($, isOn)
    const modes = e.props.modes.join(' & ')
    const toggle = () => {
      void (enabled ? turnOff($, { isManualPick: false }) : turnOn($))
    }
    return (
      <Box flexDirection="row" gap={1}>
        {modes !== '' && <Text dimColor>{modes}</Text>}
        <Button key="automodel-toggle" plain onPress={toggle}>
          <Text color={enabled ? GOLD : MUTED}>Auto Model: {enabled ? 'On' : 'Off'}</Text>
        </Button>
      </Box>
    )
  })

  // /automodel status, drawn as a card sized to the pane.
  on('ui.render', { component: 'CommandOutput', props: { command: 'automodel' } }, async ($, e, next) => {
    const arg = e.props.args.trim().toLowerCase()
    if (arg !== '' && arg !== 'status') return next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    const width = Math.max(24, (e.viewport?.columns ?? 80) - 4)
    const enabled = await read($, isOn)
    const current = await read($, session)
    const id = await $.session.id()
    const live = current !== null && current.id === id ? current : null
    const model = live?.model ?? (await $.session.model())
    const title = 'AUTO MODEL'

    const heading = (label: string) => (
      <Box flexDirection="row">
        <Text color={MUTED}>{label} </Text>
        <Text color={HAIRLINE}>{'─'.repeat(Math.max(0, width - label.length - 1))}</Text>
      </Box>
    )

    const digits = bigNumber(live?.helperJobs ?? 0)
    const isWide = width >= 56
    const tileWidth = isWide ? Math.floor((width - 1) / 2) : width
    const inner = tileWidth - 4

    const jobsTile = (
      <Box borderStyle="round" borderColor={HAIRLINE} paddingX={1} width={tileWidth} flexDirection="column">
        <Text color={MUTED}>{fit('HELPER JOBS', inner)}</Text>
        {digits.map(row => (
          <Text color={TEXT} bold>
            {fit(row, inner)}
          </Text>
        ))}
      </Box>
    )
    const modelTile = (
      <Box borderStyle="round" borderColor={HAIRLINE} paddingX={1} width={tileWidth} flexDirection="column">
        <Text color={MUTED}>{fit('LOCKED MODEL', inner)}</Text>
        <Text color={TEXT} bold>
          {fit(live === null ? 'not locked yet' : model, inner)}
        </Text>
        <Text color={MUTED}>{fit(`level ${live?.level ?? '—'}`, inner)}</Text>
        <Text color={MUTED}>{fit(live === null ? `running ${model}` : 'held for this session', inner)}</Text>
      </Box>
    )

    const flip = () => {
      void (enabled ? turnOff($, { isManualPick: false }) : turnOn($))
    }

    return (
      <Box flexDirection="column" width={width}>
        <Text color={TEXT} bold>
          {title}
        </Text>
        <Box flexDirection="row">
          <Text color={GOLD}>{'━'.repeat(title.length)}</Text>
          <Text color={HAIRLINE}>{'─'.repeat(Math.max(0, width - title.length))}</Text>
        </Box>
        {heading('STATE')}
        <Text color={enabled ? GOOD : WARN}>{fit(enabled ? 'On: sorting new sessions and side jobs' : 'Off: the model is left as it is', width)}</Text>
        <Box flexDirection={isWide ? 'row' : 'column'} gap={1}>
          {modelTile}
          {jobsTile}
        </Box>
        {heading('ACTIONS')}
        <Box flexDirection="row" gap={2}>
          <Button key="automodel-flip" plain onPress={flip}>
            <Text backgroundColor={GOLD} color={INK} bold>
              {enabled ? ' Turn off ' : ' Turn on '}
            </Text>
          </Button>
          {enabled && (
            <Button key="automodel-repick" plain onPress={() => void markRepick($)}>
              <Text backgroundColor={HAIRLINE} color={TEXT}>
                {' Repick next prompt '}
              </Text>
            </Button>
          )}
        </Box>
      </Box>
    )
  })
}
