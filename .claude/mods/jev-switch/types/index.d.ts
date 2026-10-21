declare module 'claude-code' {
  interface PluginState {
    /**
     * `nonce` only exists to redraw the band after a press. The switch itself
     * lives in `.claude/jev/state`, because a separate hook process reads it.
     */
    'jev-switch': { nonce: number }
  }
}
