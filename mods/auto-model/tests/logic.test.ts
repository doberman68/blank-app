import { describe, expect, test } from 'claude-code/testing'

import {
  bigNumber,
  decide,
  fallbackOrder,
  guessLevel,
  hasRealWork,
  isShortReply,
  levelOfModel,
  nextSession,
  parseLevel,
  resolveLines,
} from '../hooks/logic'

describe('reading the one-word answer', () => {
  test('reads each level, strongest before strong', () => {
    expect(parseLevel('small')).toBe('small')
    expect(parseLevel(' Everyday.')).toBe('everyday')
    expect(parseLevel('STRONG')).toBe('strong')
    expect(parseLevel('strongest')).toBe('strongest')
  })
  test('anything else reads as no answer', () => {
    expect(parseLevel('medium')).toBeUndefined()
    expect(parseLevel('')).toBeUndefined()
    expect(parseLevel(undefined)).toBeUndefined()
  })
})

describe('spotting a short reply', () => {
  test('fewer than four words, or a stock reply', () => {
    expect(isShortReply('yes')).toBe(true)
    expect(isShortReply('ok!')).toBe(true)
    expect(isShortReply('keep going')).toBe(true)
    expect(isShortReply('do it')).toBe(true)
    expect(isShortReply('use the second one')).toBe(false)
    expect(isShortReply('Summarize the notes in meeting.md for me')).toBe(false)
  })
})

describe('the word-based fallback', () => {
  test('sorts by the words and says strong when in doubt', () => {
    expect(guessLevel('Summarize this paragraph')).toBe('small')
    expect(guessLevel('Write an email to the team about Friday')).toBe('everyday')
    expect(guessLevel('Refactor the auth module and add tests')).toBe('strong')
    expect(guessLevel('Plan the migration of our whole codebase to the new API')).toBe('strongest')
    expect(guessLevel('hmm what about the weather patterns tomorrow')).toBe('strong')
  })
})

describe('the install model list', () => {
  test('maps levels to the lines the install offers', () => {
    const lines = resolveLines(['default', 'haiku', 'sonnet', 'opus', 'fable'])
    expect(lines).toEqual({ small: 'haiku', everyday: 'sonnet', strong: 'opus', strongest: 'fable' })
  })
  test('a missing line is left out so the pick steps down', () => {
    const lines = resolveLines(['default', 'sonnet', 'opus'])
    expect(lines.strongest).toBeUndefined()
    expect(fallbackOrder('strongest')).toEqual(['strongest', 'strong', 'everyday', 'small'])
  })
  test('reads a model value back to its level', () => {
    expect(levelOfModel('claude-sonnet-5-5')).toBe('everyday')
    expect(levelOfModel('something-new')).toBe('strong')
  })
})

describe('the lock', () => {
  test('the first prompt of a session picks the model', () => {
    expect(decide('fresh', undefined, 'everyday', 'Draft a post about our launch')).toEqual({
      setLevel: 'everyday',
      lockLevel: 'everyday',
    })
  })

  test('a later prompt that sorts lower stays locked', () => {
    const decision = decide('locked', 'strong', 'small', 'What time zone is Chicago in?')
    expect(decision.setLevel).toBeUndefined()
    expect(decision.lockLevel).toBe('strong')
    expect(decision.helperLevel).toBeUndefined()
  })

  test('steps up once when a later prompt sorts higher, never back down', () => {
    const up = decide('locked', 'everyday', 'strong', 'Build the import pipeline across these services')
    expect(up).toEqual({ setLevel: 'strong', lockLevel: 'strong' })
    const after = decide('locked', up.lockLevel, 'everyday', 'Write a quick note to Sam')
    expect(after.setLevel).toBeUndefined()
    expect(after.lockLevel).toBe('strong')
  })

  test('picks fresh after /clear, down as well as up', () => {
    expect(decide('fresh', 'strongest', 'small', 'Translate this sentence to German')).toEqual({
      setLevel: 'small',
      lockLevel: 'small',
    })
  })

  test('helper counts carry within a session and restart in a new one', () => {
    const held = { id: 's1', model: 'opus', level: 'strong' as const, isFresh: false, isHelperPending: false, helperJobs: 3 }
    expect(nextSession(held, 's1', 'opus', { lockLevel: 'strong' }).helperJobs).toBe(3)
    expect(nextSession(held, 's2', 'opus', { lockLevel: 'strong' }).helperJobs).toBe(0)
  })
})

describe('the helper note', () => {
  test('only a smaller job with real work that stands on its own', () => {
    expect(decide('locked', 'strong', 'small', 'Summarize notes/meeting.md into five bullets').helperLevel).toBe('small')
    expect(decide('locked', 'strong', 'everyday', 'Reformat contacts.csv as a markdown table').helperLevel).toBe(
      'everyday',
    )
  })
  test('not for a one-line question', () => {
    expect(decide('locked', 'strong', 'small', 'What is the capital of Peru?').helperLevel).toBeUndefined()
  })
  test('not when it depends on the conversation', () => {
    expect(decide('locked', 'strong', 'small', 'Summarize what we discussed above in three bullets').helperLevel).toBeUndefined()
  })
  test('not when the job is as hard as the locked model', () => {
    expect(decide('locked', 'everyday', 'everyday', 'Draft a reply to this email').helperLevel).toBeUndefined()
  })
  test('real work is reading, reformatting or drafting', () => {
    expect(hasRealWork('rename these files')).toBe(true)
    expect(hasRealWork('how are you')).toBe(false)
  })
})

describe('big numbers', () => {
  test('three rows, equal width', () => {
    const rows = bigNumber(42)
    expect(rows).toHaveLength(3)
    expect(rows[0].length).toBe(rows[1].length)
    expect(rows[1].length).toBe(rows[2].length)
  })
})
