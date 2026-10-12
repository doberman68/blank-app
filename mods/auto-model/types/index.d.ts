export type AutoModelLevel = 'small' | 'everyday' | 'strong' | 'strongest'

export type AutoModelSession = {
  /** The session id the lock belongs to; a /clear starts a new one. */
  id: string
  /** The main model value set (or adopted) for this session. */
  model: string
  /** The level that chose it. */
  level: AutoModelLevel
  /** The next typed prompt picks fresh, up or down (compaction, /automodel repick). */
  isFresh: boolean
  /** A helper note was attached to the prompt now running. */
  isHelperPending: boolean
  /** Jobs handed to helper agents this session. */
  helperJobs: number
}

declare module 'claude-code' {
  interface PluginState {
    'auto-model': { isOn: boolean; session: AutoModelSession | null }
  }
}
