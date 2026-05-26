import { describe, it, expect } from 'vitest'
import { isNoopResponse } from '../heartbeat.js'

/* Kanban-card b71579c1 (Geza 2026-05-26): the heartbeat agent paradoxically
 * sent "Csendes ablak. Nem küldök Telegram pinget" through Telegram, because
 * the code unconditionally forwarded the LLM response. The fix asks the
 * agent to reply with literal NOOP on quiet windows and filters that out
 * here -- these tests pin the sentinel-detection behaviour. */
describe('heartbeat NOOP sentinel detection', () => {
  it('bare NOOP -> true', () => {
    expect(isNoopResponse('NOOP')).toBe(true)
  })
  it('NOOP with trailing period -> true (LLM punctuation drift)', () => {
    expect(isNoopResponse('NOOP.')).toBe(true)
  })
  it('NOOP wrapped in whitespace / newlines -> true', () => {
    expect(isNoopResponse('   NOOP\n')).toBe(true)
    expect(isNoopResponse('\n NOOP. \n')).toBe(true)
  })
  it('case-insensitive: noop / Noop -> true', () => {
    expect(isNoopResponse('noop')).toBe(true)
    expect(isNoopResponse('Noop')).toBe(true)
  })
  it('null / undefined / empty -> true (treat as nothing to send)', () => {
    expect(isNoopResponse(null)).toBe(true)
    expect(isNoopResponse(undefined)).toBe(true)
    expect(isNoopResponse('')).toBe(true)
    expect(isNoopResponse('   ')).toBe(true)
  })

  it('the historical paradox message is NOT a NOOP (would have been blocked elsewhere)', () => {
    // We intentionally don't pattern-match the Hungarian message itself -- the
    // contract is "agent returns literal NOOP", not "code parses prose". Old
    // paradox text passes the NOOP filter and would still be forwarded; the
    // prompt-side instruction is what prevents the LLM from emitting it.
    const paradox =
      'Csendes ablak. Nem küldök Telegram pinget, semmi sem indokolja.'
    expect(isNoopResponse(paradox)).toBe(false)
  })
  it('real heartbeat summary -> false', () => {
    const summary =
      '🩺 HEARTBEAT — 2026.05.26 18:00\n\nKanban: 2 urgent.'
    expect(isNoopResponse(summary)).toBe(false)
  })
  it('a string containing NOOP somewhere is NOT a sentinel match', () => {
    expect(isNoopResponse('NOOP found, also there was a meeting'))
      .toBe(false)
  })
})
