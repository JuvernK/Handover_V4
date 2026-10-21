import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

/**
 * The Jev router's switch, as a pressable control above the prompt.
 *
 * The switch state is not kept here. It lives in `.claude/jev/state`, because
 * the router itself is a `UserPromptSubmit` hook running as its own process,
 * and that file is the only thing both sides can see. This mod reads the file
 * to draw, and writes it on a press.
 *
 * The band is drawn only where that file exists, so the mod stays invisible in
 * projects that have no Jev router set up.
 */

const STATE_PATH = '.claude/jev/state'

// Bumped on every press, so the band redraws right after a write.
const nonce = atom({ plugin: 'jev-switch', key: 'nonce' } as const, 0)

/**
 * The state file, absolute. Built from the session's project root rather than
 * left relative, so the switch still works when Claude Code was started in a
 * subdirectory of the project.
 */
async function stateFile($: EngineInterface): Promise<string> {
  return `${await $.session.root()}/${STATE_PATH}`
}

/** `true` on, `false` off, `null` where this project has no Jev router. */
async function readSwitch($: EngineInterface): Promise<boolean | null> {
  try {
    return (await $.fs.read(await stateFile($))).trim() === 'on'
  } catch {
    return null
  }
}

export const register: Register = on => {
  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    // Registering as a reader of `nonce` is what makes a press redraw this.
    await read($, nonce)
    const isOn = await readSwitch($)

    if (isOn === null || e.props.hasSurvey) {
      return next(e)
    }

    const { Box, Button, Text } = $.ui.resolve(e)

    const flip = async () => {
      await $.fs.write(await stateFile($), isOn ? 'off\n' : 'on\n')
      await update($, nonce, n => n + 1)
      $.ui.toast(isOn ? 'Jev router off' : 'Jev router on')
    }

    // The dot carries the state as shape as well as color, so the band still
    // reads at a glance in a terminal with no color and to a colorblind eye.
    return (
      <Box gap="sm" alignItems="center">
        <Button
          key="jev-switch"
          hotkey="j"
          variant={isOn ? 'primary' : 'secondary'}
          onPress={flip}
        >
          {isOn ? '\u25cf Jev on' : '\u25cb Jev off'}
        </Button>
        <Text size="caption" color="subtle">
          {isOn ? 'routing every prompt' : 'prompts go straight to Claude'}
        </Text>
      </Box>
    )
  })
}
