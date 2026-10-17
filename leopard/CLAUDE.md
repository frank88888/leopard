# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

BAR 台 (Taiwanese arcade fruit machine) simulator in Godot 4.4 / GDScript. Virtual credits only. The full spec is `docs/SPEC.md` (Traditional Chinese) — read it before changing rules; section 16 has keys, file paths and commands.

## Commands

Godot is not on PATH; a copy lives at `C:\Users\frank\tools\godot\Godot_v4.4.1-stable_win64_console.exe` (use `$G` below).

```
$G --headless --path . --import                                     # needed once after adding new class_name scripts
$G --headless --path . -s tests/run_tests.gd                        # all tests (custom runner, no GUT); exit code 1 on failure
$G --headless --path . -s tools/simulate_rtp.gd -- 1000000 all      # RTP simulation: all | single | random
$G --path . --resolution 540x720 -s tools/screenshot.gd -- <dir>    # windowed; scripted playthrough → PNGs (writes then deletes user://save.json)
```

There is no single-test flag: edit the calls in `_init()` of `tests/run_tests.gd`.

## Architecture

- `scripts/core/` is pure logic (RefCounted, no nodes) so tests and the simulator run headless. `GameState` is the facade: credit/win/bets, `start()`, `finish_round()`, `collect()`, `double_up()`, `serialize()/restore()`. UI only calls these and listens to signals.
- Outcome is decided **before** animation: `GameState.start()` → `_resolve()` draws symbol(s) from `OddsTable`, picks a ring cell, stores the whole round (incl. LUCK bonus spins) in `round_data`. `SpinPlan` then builds step intervals so the light lands exactly on the pre-chosen cell. Save happens between decision and animation (`round_started`), so power loss restores from the saved result without re-drawing.
- Odds: `p_i = c / multiplier_i`, `c = rtp_target / (1 + E[bonus]·luck_bonus_prob)`; remainder = LUCK-miss. Changing multipliers/rtp/luck prob can overflow total probability — `GameConfig.odds_valid()` guards the back office.
- Repeat-bet is merged into the start button (`GameState.start()`): no manual bets + memory → repeat, scaled by largest remainder if CREDIT is short; WIN>0 is auto-collected first.
- `scripts/ui/main.gd` builds the whole UI in code (`scenes/main.tscn` is just a root Control) and drives animation with `await` loops; `hud_lock` freezes HUD numbers during count-up animations, `busy` locks input.
- Config: `config/*.json` are factory defaults; back-office edits go to `user://overrides.json` (checksummed via `SaveData`). Save payload is stored as a string inside the JSON so the SHA-256 survives int/float round-tripping.
- Art and audio are generated in code (`symbol_icon.gd`, `sfx_player.gd`); there are no external assets.

## GDScript gotchas seen here

- `:=` fails on untyped loop variables / untyped dictionary values — declare the type explicitly.
- Typed arrays (`Array[int]`) don't compare equal to untyped literals; build a typed variable first.
- Heredocs with Chinese text in Bash tool calls failed once; use the Write tool for source files.

## Git rules

- Claude may write commit messages and run `git add` / `git commit` (new commits only) when the user asks. Add the Co-Authored-By trailer.
- Never destroy prior work. Forbidden: `git reset` (any mode), deleting or rewriting commits (`commit --amend`, `rebase`, `filter-branch`, `commit-tree` tricks, `reflog expire`/`gc --prune`), force push (`--force`, `-f`, `--force-with-lease`), deleting branches/tags (`branch -D`, `tag -d`, `push --delete`), `git clean`, `git checkout -- <path>` / `git restore` that discards uncommitted changes, `git stash drop/clear`.
- To undo something, use `git revert` (adds a new commit) or ask the user first.
- Don't `git push` unless the user explicitly asks.
