# ci-cache-scope-lab — validation harness

Minimal, benign reproduction of GitHub Actions **cache poisoning across the
default-branch cache scope**, with the platform condition that makes it
possible stated explicitly.

## What is under test

GitHub grants `workflow_run` (and `pull_request_target`, `issue_comment`) a
**read-only** cache token on the default branch by default, so a `cache-to` /
`actions/cache/save` from such a workflow is denied. A repository can opt out
by declaring `cache-mode: write` (or `write-only`) on the workflow or job. The
chain under test is:

1. attacker opens a PR (no approval needed for the `pr` workflow to run);
2. `cache-writer` (`workflow_run`, `cache-mode: write`) checks out the PR head
   SHA and runs `src/build.sh` **from that commit**;
3. the result is saved under the fixed key `lab-dist-v1`;
4. `release` (`push` on `main`, trusted) restores `lab-dist-v1` and runs
   `dist/run.sh`, then packages `dist/` as an artifact.

If the artifact contains the attacker's marker, the untrusted PR has injected
content into the trusted release job without any maintainer approval.

## Workflows

| File | Trigger | Cache access | Role |
|---|---|---|---|
| `pr.yml` | `pull_request` | default (merge-ref scope) | untrusted PR build, starts the chain |
| `cache-writer.yml` | `workflow_run` on `pr` | **`cache-mode: write`** (opt-in) | writes `lab-dist-v1` from the PR head commit |
| `chained.yml` | `workflow_run` on `pr` | **`cache-mode: write`** (opt-in) | buildx `cache-to: type=gha,scope=lab` from the PR head commit |
| `release.yml` | `push` on `main`, `workflow_dispatch` | default `write` | restores `lab-dist-v1`, runs it, uploads artifact |
| `main-build.yml` | `push` on `main` | default `write` | buildx `cache-from: type=gha,scope=lab` |

All payloads are text markers (`legit-<sha>` / `POISONED-<sha>`). No secrets,
no network, no persistent side effects beyond one cache entry and one artifact.

## Test matrix (expected results)

| # | Step | Expected evidence | Proves |
|---|---|---|---|
| T0 | Harness merged to `main`; `release` runs on the push | `cache_hit=false`, `marker=none`, run step skipped | clean baseline, no cache yet |
| T1 | Push `attacker-cache` (03b146b) to the second account's repo as `attacker-fork`, open a cross-repo PR to `main` | `cache-writer`: `save_outcome=success`; `chained`: cache export succeeds | low-trust workflow **can** write with the opt-in |
| T2 | `workflow_dispatch` on `release` (main) | `cache_hit=true`, `marker=POISONED-…`, `dist/run.sh` prints the attacker line, artifact `release-dist` contains the marker; buildx `RUN` step **not** `CACHED` (content-addressed on `src/`) | trusted consumer executes attacker content; buildx limit |
| T3 | Delete cache `lab-dist-v1`, repeat with a legit PR | `marker=legit-…`, artifact contains the legit marker | the cache content, not the workflow, decides the output |
| T4 | Remove `cache-mode: write` from `cache-writer`, repeat T1 | `cache_mode=read`, `save_outcome=failure` with a cache write denied message; T2 then gives `cache_hit=false` | the opt-in is the necessary condition (A/B) |

## Running it

The `workflow_run` and `push` workflows execute from the **default branch**, so
the harness must be on `main`. The attacker PR comes from a second account
(cross-repo PR): that is what makes the checkout guard fire without the
`allow-unsafe-pr-checkout: true` opt-in (observed on runs 45805529388 and
45800155385, before the opt-in was added). With the opt-in the fork head is
checked out and its `src/build.sh` runs in the `cache-writer` job. Order:
T0 → T1 → T2 → T3 → T4. T3 (cache deletion) requires write access to the base
repo, i.e. the owner account. Collect logs with `gh run view <id> --log` or
from the Actions tab, and the artifact from the `release` run. Cleanup:
Actions → Caches → delete `lab-dist-v1`, close the PR, delete the branches.

## Scope note

This repository demonstrates the mechanism only. It is not evidence against
any third-party repository; a report is submittable only if an in-scope
repository has the same opt-in on a low-trust trigger and a trusted consumer
that ships what it restores.
