# CLAUDE.md

This file provides global guidance to Claude Code when working in Jean's development environment.

## Project Organization

All projects live under `~/projects/`. Each project is its own git repository with two standard files:

### CLAUDE.md (Project-Specific Instructions)
- How to build, test, lint, and deploy the project
- Architecture overview and key patterns
- Technology stack and dependencies
- Common tasks and workflows
- Project-specific conventions

### WORKLOG.md (Session History)
- Diary of work sessions with Claude
- What was investigated, changed, decided, and why
- Reasoning behind architectural decisions
- Issues encountered and how they were resolved
- Updated after every work session
- When returning to a project after days/weeks, read this first to understand context

## Dotfiles Management

Configuration is managed with [chezmoi](https://www.chezmoi.io/) at `~/.local/share/chezmoi/`.

This repo contains:
- Shell configuration (~/.zshrc, etc.)
- Terminal configuration
- Claude Code settings
- Application configs
- This global CLAUDE.md file

Files are managed with chezmoi and symlinked/templated to their expected locations. Changes should be:
1. Made to source files in `~/.local/share/chezmoi/`
2. Applied with `chezmoi apply`
3. Committed to git for version control

## General Workflow Preferences

### File Organization
- Keep CLAUDE.md focused on "how to work with this codebase"
- Keep WORKLOG.md as a chronological session diary
- Update WORKLOG.md at the end of each work session
- Never duplicate information between global and project CLAUDE.md files

### Documentation Philosophy
- CLAUDE.md: Reference material that rarely changes
- WORKLOG.md: Living history that grows with each session
- README.md: User-facing project documentation

### Worklog Trimming

When WORKLOG.md grows too large and risks filling the context window with stale history, compress it using these rules:

**Delete**:
- Anything recoverable from git history (commit messages, diffs)
- Anything visible in the current codebase
- Step-by-step implementation details of completed work
- Resolved issues that are no longer relevant

**Condense**:
- Old completed work into brief summaries
- Multiple sessions on the same topic into single entries
- Routine maintenance work into one-line notes

**Keep**:
- Open questions and unresolved issues
- Key architectural decisions and their reasoning
- Active experiments and ongoing investigations
- Trade-offs considered and why certain approaches were chosen
- Context that isn't obvious from code or git history
- Pitfalls and gotchas discovered during development

**Goal**: Keep the context window focused on what actually matters for current and future work, not filled with historical details that are preserved elsewhere.

### Working on Projects

When starting work on a project:
1. Navigate to `~/projects/{project-name}/`
2. Read CLAUDE.md to understand the project
3. Read WORKLOG.md to understand recent context
4. Proceed with the work

When ending a work session:
1. Update WORKLOG.md with what was done
2. Update CLAUDE.md if architecture or processes changed
3. Commit changes

### Git Workflow
- Make focused, atomic commits with clear messages following the semantic commit format

### Communication Style
- Be concise and direct
- Focus on facts and problem-solving
- Avoid unnecessary superlatives or excessive praise
- Ask clarifying questions when requirements are ambiguous
- Provide clear explanations for technical decisions

## Tool Preferences

### Package Managers
- Node.js projects: Use `pnpm` by default (check package.json scripts)
- Python projects: Use `uv` by default (check for poetry, pipenv, or requirements.txt)
- Always use the package manager the project already uses

### Testing
- Run tests before committing
- Respect git hooks (pre-commit, pre-push)
- Fix failing tests before moving on
- Add tests for new features

## This File

This file should evolve as workflow preferences become clear. Update it when:
- New organizational patterns emerge
- Tool preferences change
- Common issues have consistent solutions
- Cross-project patterns are established

Keep it focused on information that applies across all projects, not project-specific details.
