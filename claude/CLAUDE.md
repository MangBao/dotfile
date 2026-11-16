# Global Agent Rules

## Planning (large tasks only)
- Create task_plan.md (max 20 lines), findings.md, progress.md at project root
- Re-read task_plan.md at start of each session after /clear
- Phase gate: update progress.md before moving to next phase

## Code Discipline
- Ask clarifying questions before coding ambiguous requests
- Surgical edits only — never reformat whole files
- No extra abstractions unless explicitly asked (YAGNI)
- Return: diff + 3-bullet reason. No preamble.

## Response Format
- Terse prose, no pleasantries
- Code block + short bullets only
- If uncertain: say so in one line, ask one question

## Terminal Output
- Prefer quiet flags (-q, --silent, --quiet) for installs, builds and test runs
- Pipe long output through a filter (tail, Select-Object -Last N) instead of dumping it

## Security
- Never run destructive commands without explicit confirmation
- Flag any hardcoded secrets immediately
- Never run `git commit`, `git push`, or any command that creates or updates a remote branch unless the user explicitly asks in the current message
- Prepare changes and show the proposed commit message; wait for confirmation before committing or pushing
