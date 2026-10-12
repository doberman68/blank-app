import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On } from 'claude-code'

const USAGE = { input_tokens: 1, output_tokens: 1, cache_creation_input_tokens: 0, cache_read_input_tokens: 0 }
const OPTIONS = ['default', 'haiku', 'sonnet', 'opus', 'fable']

/** The world beneath the mod: one session whose model the /config row sets. */
function world(on: On, start: { model: string; level?: string; underway?: boolean }) {
  const held = { level: start.level ?? 'strong', isClassifierDown: false, model: start.model, id: 'session-1', underway: start.underway ?? false, contexts: [] as string[][] }
  mock.store(on)
  mock.clock(on, { now: 1_000_000 })
  on('command.register', ($, e) => ({ value: { command: e.name } }))
  on('session.start', ($, e) => ({ cwd: e.cwd }))
  on('session.end', ($, e) => ({ sessionId: e.sessionId }))
  on('ui.status', () => ({ value: undefined }))
  on('session.id', () => ({ value: held.id }))
  on('session.model', () => ({ value: held.model }))
  on('session.messages', () => ({ value: held.underway ? [{ role: 'assistant', text: 'earlier', toolUses: [] }] : [] }))
  on('config.list', () => ({ value: [
    {
      key: 'model',
      label: 'Model',
      kind: 'choice',
      value: held.model,
      options: OPTIONS,
      provider: { plugin: 'engine', tier: 'core' },
      isLocked: false,
    },
  ] }))
  on('config.set', ($, e) => {
    held.model = String(e.value)
    return { value: e.value }
  })
  on('model.complete', () => ({
    value: held.isClassifierDown
      ? { isAnswered: false as const, reason: 'aborted' as const, usage: USAGE }
      : { isAnswered: true as const, text: held.level, usage: USAGE },
  }))
  on('prompt.submit', ($, e) => {
    held.contexts.push([...(e.context ?? [])])
    return { text: e.text, context: e.context }
  })
  on('command.run', ($, e) => ({ text: `engine ran ${e.command}` }))
  return held
}

const typed = (text: string) => ({ text, wait: false, origin: { kind: 'composer' as const } })

async function begin($: Engine) {
  await $.session.start({ cwd: '/work', surface: 'terminal', isInteractive: true })
  await $.command.run({ command: 'automodel', args: 'on', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 100 } })
}

test('the first typed prompt of a session sets the main model', async ($, on) => {
  const held = world(on, { model: 'opus', level: 'small' })
  await begin($)
  await $.prompt.submit(typed('Translate this list of phrases into Spanish please'))
  expect(held.model).toBe('haiku')
})

test('a resumed session keeps its model', async ($, on) => {
  const held = world(on, { model: 'opus', level: 'small', underway: true })
  await begin($)
  await $.prompt.submit(typed('Translate this list of phrases into Spanish please'))
  expect(held.model).toBe('opus')
})

test('a short reply and a slash command are never sorted', async ($, on) => {
  const held = world(on, { model: 'sonnet', level: 'strongest' })
  await begin($)
  await $.prompt.submit(typed('Draft a post about the launch event'))
  held.model = 'sonnet'
  await $.prompt.submit(typed('yes do it'))
  expect(held.model).toBe('sonnet')
})

test('turning it off leaves the current model and attaches no note', async ($, on) => {
  const held = world(on, { model: 'opus', level: 'everyday' })
  await begin($)
  await $.prompt.submit(typed('Draft a post about the launch event'))
  expect(held.model).toBe('sonnet')
  const off = await $.command.run({ command: 'automodel', args: 'off', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 100 } })
  expect(off.text).toContain('off')
  expect(held.model).toBe('sonnet')
  await $.prompt.submit(typed('Build the whole billing service from scratch now'))
  expect(held.model).toBe('sonnet')
  expect(held.contexts.at(-1)).toEqual([])
})

test('status names the locked model, its level and helper jobs', async ($, on) => {
  world(on, { model: 'opus', level: 'strong' })
  await begin($)
  await $.prompt.submit(typed('Refactor the importer and add tests for it'))
  const status = await $.command.run({ command: 'automodel', args: 'status', origin: { kind: 'composer' }, presentation: { isFullscreen: true, columns: 100 } })
  expect(status.text).toContain('Locked model: opus')
  expect(status.text).toContain('level: strong')
  expect(status.text).toContain('helpers this session: 0')
})

test('the switch and the status card fit narrow and wide panes', async ($, on) => {
  world(on, { model: 'opus', level: 'strong' })
  await begin($)
  for (const surface of ['terminal', 'desktop'] as const) {
    const bar = await $.ui.mount({ plugin: 'auto-model', surface, component: 'SessionMode', props: { modes: [] } })
    expect((await bar.find({ key: 'automodel-toggle' }))?.text).toContain('Auto Model: On')
    await bar.press({ key: 'automodel-toggle' })
    expect((await bar.find({ key: 'automodel-toggle' }))?.text).toContain('Auto Model: Off')
    await bar.press({ key: 'automodel-toggle' })
    await bar.unmount()

    for (const columns of [40, 140]) {
      const card = await $.ui.mount({
        plugin: 'auto-model',
        surface,
        component: 'CommandOutput',
        props: { command: 'automodel', args: 'status', text: '', isErrored: false },
        viewport: { columns, rows: 40 },
      })
      const texts = await card.findAll({ type: 'Text' })
      for (const one of texts) expect(one.text.length).toBeLessThanOrEqual(columns)
      expect(await card.find({ key: 'automodel-flip' })).toBeDefined()
      await card.unmount()
    }
  }
})

test('after /clear the next prompt picks fresh, down as well as up', async ($, on) => {
  const held = world(on, { model: 'opus', level: 'strongest' })
  await begin($)
  await $.prompt.submit(typed('Plan the migration of our whole platform'))
  expect(held.model).toBe('fable')
  await $.session.end({ reason: 'clear', sessionId: held.id, resume: { sessionId: held.id } as never })
  held.id = 'session-2'
  held.level = 'small'
  await $.prompt.submit(typed('Summarize notes.md into five bullets'))
  expect(held.model).toBe('haiku')
})

test('a later prompt that sorts higher steps up once and never back down', async ($, on) => {
  const held = world(on, { model: 'opus', level: 'everyday' })
  await begin($)
  await $.prompt.submit(typed('Draft a post about the launch event'))
  expect(held.model).toBe('sonnet')
  held.level = 'small'
  await $.prompt.submit(typed('Summarize notes.md into five bullets'))
  expect(held.model).toBe('sonnet')
  expect(held.contexts.at(-1)?.[0]).toContain('helper agent')
  held.level = 'strong'
  await $.prompt.submit(typed('Refactor the importer and add tests for it'))
  expect(held.model).toBe('opus')
  held.level = 'everyday'
  await $.prompt.submit(typed('Write a short email to the team about Friday'))
  expect(held.model).toBe('opus')
})

test('when the quick check fails the words decide', async ($, on) => {
  const held = world(on, { model: 'opus' })
  held.isClassifierDown = true
  await begin($)
  await $.prompt.submit(typed('Translate this list of phrases into Spanish please'))
  expect(held.model).toBe('haiku')
})
