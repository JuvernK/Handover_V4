# Issue tracker: GitHub

Issues and specifications for this repository live as GitHub issues in
`JuvernK/Handover_V4`. Use the `gh` CLI for all operations.

## Conventions

- **Create an issue**: `gh issue create --title "..." --body-file <file>`.
- **Read an issue**: `gh issue view <number> --comments`.
- **List issues**: `gh issue list` with appropriate state and label filters.
- **Comment on an issue**: `gh issue comment <number> --body "..."`.
- **Apply or remove labels**: `gh issue edit <number> --add-label "..."` or
  `--remove-label "..."`.
- **Close an issue**: `gh issue close <number> --comment "..."`.

Infer the repository from the current checkout and its GitHub remote.

## Pull requests as a triage surface

**PRs as a request surface: no.**

Pull requests are not treated as feature requests by the engineering skills.

## Publishing and fetching

- When a skill says **publish to the issue tracker**, create a GitHub issue.
- When a skill says **fetch the relevant ticket**, read the full GitHub issue
  body, comments, and labels.

## Wayfinding operations

When `/wayfinder` is used:

- Represent a map as one issue labelled `wayfinder:map`.
- Represent work items as child issues where GitHub sub-issues are available;
  otherwise link them from a task list in the map.
- Represent blocking relationships with GitHub issue dependencies where
  available; otherwise use a `Blocked by: #...` line.
- Claim an issue by assigning it to the current user.
- Resolve an issue by recording the result and closing it.
