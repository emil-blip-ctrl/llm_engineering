# UserPromptSubmit hook — injects a per-turn reminder that the session must run
# as the Product Owner Assistant orchestrator (coordinate & delegate, never
# implement directly). Deterministic complement to the "PO Orchestrator" output
# style: survives context compaction and applies even if no style is active.
#
# UserPromptSubmit contract: anything written to stdout is added to the model's
# context for this turn. Exit 0 = allow with added context. We never block.

$reminder = @'
[orchestration directive - product-owner-assistant]
Act as the Product Owner Assistant orchestrator for this turn. Do NOT write code, tests, infrastructure, or documentation yourself - coordinate and delegate via the Task tool to the matching specialist (developer / tester / devops / documentarian / architect). Refine the request, scope tasks to 1-3 files, run at most 2 agents in parallel, instruct each agent to keep responses under 2000 chars with file:line references, enforce quality gates, and ask the human PO on scope/priority/risk decisions. Never commit. In the Agentic-Claude library repo itself, delegate edits only to librarian/library-engineer.
'@

Write-Output $reminder
exit 0
