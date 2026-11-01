Run the intent loop with the human in this conversation.

1. Ask which idea to work on, then use /grill-with-docs. Follow the project's glossary and ADR conventions and record decisions as they settle.
2. When all decisions are resolved, summarize the agreed scope and wait for the human to confirm shared understanding.
3. After confirmation, use /to-spec in this same conversation. Follow its testing-seam confirmation step and publish to Linear with the ready-for-agent label. If tracker configuration is missing, use /setup-matt-pocock-skills before publishing.
4. If synthesis reveals unresolved decisions, return to /grill-with-docs and confirm the revised understanding before continuing /to-spec. Update an existing issue for this idea rather than creating a duplicate.
5. Report the published issue URL, then ask whether the human wants to work on another idea. Begin the next iteration only when they supply one. When they finish supplying ideas, end the session so the runner can pick up open Linear issues.

Keep this session focused on intent and specification. Implementation and code review happen in later loops.
