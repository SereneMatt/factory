# Factory v1

The intent loop turns an idea into an agreed spec, ready for an agent to build.

```text
Idea → /grill-with-docs → Confirm shared understanding → /to-spec → Ready for agent
            ↑                                          │
            └──────── Revisit unresolved decisions ─────┘
```

Run both skills in the same conversation so `/to-spec` retains the interview context.

Start an interactive Grok session in the target repository:

```bash
./v1/intent.sh /path/to/repo
```

Grok must have the mattpocock skills installed, including `/grill-with-docs`, `/to-spec`, and their dependencies. The runner passes [the intent prompt](v1/intent.md) explicitly when starting the session.

1. Run `/grill-with-docs` on one idea. Resolve decisions with the human, record agreed domain terms in the glossary, and capture ADRs when the trade-off warrants one.
2. Summarize the agreed scope and wait for the human to confirm shared understanding.
3. Run `/to-spec`. Confirm the testing seams with the human, then publish the spec to the configured project issue tracker with the `ready-for-agent` label. Configure the tracker through `/setup-matt-pocock-skills` if needed.
4. If synthesis exposes an unresolved decision, return to `/grill-with-docs` before publishing. Continue in the same conversation and update the existing spec if one was already published.
5. The iteration ends when the issue URL is available and the spec reflects the confirmed decisions. Start another iteration for the next idea.

The intent loop produces specs, glossary updates, and warranted ADRs. Implementation and code review follow in later loops.
