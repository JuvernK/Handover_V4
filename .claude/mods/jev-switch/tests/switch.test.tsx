import { expect, test } from 'claude-code/testing'
import type { On } from 'claude-code'

/** Stands in for the engine's own drawing, for the cases where the mod passes. */
function engineDraws(on: On) {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)

    return <Text>engine</Text>
  })
}

// The band is drawn on both, and each surface checks the tree by its own table.
const SURFACES = ['terminal', 'desktop'] as const

const BAND_PROPS = {
  hasSurvey: false,
  isWorking: false,
  maxRows: 10,
  bodyColumns: 80,
  scroll: { offset: 0, bodyRows: 10 },
  view: {},
}

const BAND = {
  plugin: 'jev-switch',
  component: 'AbovePrompt',
  requestId: 'above-prompt',
  props: BAND_PROPS,
} as const

/**
 * Stands in for the state file. The engine sits beneath the plugin in a test,
 * so these two hooks are the filesystem as far as the mod can tell.
 */
function fakeStateFile(on: On, initial: string | null) {
  let contents = initial
  const ROOT = '/project'

  on('session.root', () => ({ value: ROOT }))

  on('fs.read', (_, e) => {
    if (e.path !== `${ROOT}/.claude/jev/state`) {
      throw new Error(`unexpected read: ${e.path}`)
    }

    if (contents === null) {
      throw new Error(`no such file: ${e.path}`)
    }

    return { value: contents }
  })

  on('fs.write', (_, e) => {
    if (e.path !== `${ROOT}/.claude/jev/state`) {
      throw new Error(`unexpected write: ${e.path}`)
    }

    contents = e.text

    return { value: undefined }
  })

  return () => contents
}

for (const surface of SURFACES) {
test(`the switch reads off, and a press turns it on (${surface})`, async ($, on) => {
  const contents = fakeStateFile(on, 'off\n')
  on('ui.toast', () => ({ value: undefined }))

  const ui = await $.ui.mount({ ...BAND, surface })

  expect((await ui.find({ key: 'jev-switch' }))?.text).toContain('Jev off')

  await ui.press({ key: 'jev-switch' })

  expect(contents()).toBe('on\n')
  expect((await ui.find({ key: 'jev-switch' }))?.text).toContain('Jev on')

  await ui.unmount()
})
}

for (const surface of SURFACES) {
test(`a press while on turns it off again (${surface})`, async ($, on) => {
  const contents = fakeStateFile(on, 'on\n')
  on('ui.toast', () => ({ value: undefined }))

  const ui = await $.ui.mount({ ...BAND, surface })

  expect((await ui.find({ key: 'jev-switch' }))?.text).toContain('Jev on')

  await ui.press({ key: 'jev-switch' })

  expect(contents()).toBe('off\n')
  expect((await ui.find({ key: 'jev-switch' }))?.text).toContain('Jev off')

  await ui.unmount()
})
}

for (const surface of SURFACES) {
test(`a read that fails after a good one keeps the band (${surface})`, async ($, on) => {
  // The engine caches one draw per distinct props value, and idle props are
  // identical at session start and after a turn. A failed read that returned
  // no band would therefore be cached, and the switch would only reappear
  // while a turn churned the props. The last known state is served instead.
  let readable = true
  const ROOT = '/project'

  on('session.root', () => ({ value: ROOT }))
  on('ui.toast', () => ({ value: undefined }))
  on('fs.read', (_, e) => {
    if (!readable) {
      throw new Error(`unreadable: ${e.path}`)
    }

    return { value: 'on\n' }
  })

  const good = await $.ui.mount({ ...BAND, surface })

  expect((await good.find({ key: 'jev-switch' }))?.text).toContain('Jev on')

  await good.unmount()

  readable = false
  const degraded = await $.ui.mount({ ...BAND, surface })

  expect((await degraded.find({ key: 'jev-switch' }))?.text).toContain('Jev on')

  await degraded.unmount()
})
}

for (const surface of SURFACES) {
test(`no state file means no band at all (${surface})`, async ($, on) => {
  fakeStateFile(on, null)
  engineDraws(on)

  const ui = await $.ui.mount({ ...BAND, surface })

  expect(await ui.find({ key: 'jev-switch' })).toBeUndefined()

  await ui.unmount()
})
}

for (const surface of SURFACES) {
test(`the switch yields the band to a survey (${surface})`, async ($, on) => {
  fakeStateFile(on, 'on\n')
  engineDraws(on)

  const ui = await $.ui.mount({
    ...BAND,
    props: { ...BAND_PROPS, hasSurvey: true },
    surface,
  })

  expect(await ui.find({ key: 'jev-switch' })).toBeUndefined()

  await ui.unmount()
})
}
