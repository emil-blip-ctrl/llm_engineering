---
name: agile-user-stories
version: 1.0.0
type: methodological
category: business-analysis
standards:
  - Connextra user story format (Cohn, 2004)
  - INVEST criteria (Wake, 2003)
  - MoSCoW prioritisation
  - BDD / Gherkin acceptance criteria
description: >
  Write, split, and refine agile user stories with well-formed acceptance criteria.
  Applies the Connextra format, INVEST criteria, and MoSCoW prioritisation. Use when
  building or grooming a product backlog, refining epics into stories, or preparing
  stories for sprint planning.
allowed-tools: Read, Write, Edit, Grep, Glob, TodoWrite, AskUserQuestion, mcp__claude_ai_Atlassian__*
---

# /agile-user-stories — User Story Authoring

## Step 1: Write the Story (Connextra format)

```
As a <role>,
I want <capability>,
So that <business value>.
```

- **Role** — a specific user type, not "user" (e.g., "authenticated policyholder")
- **Capability** — one concrete thing (not "manage X" — too broad)
- **Value** — the outcome/benefit, not the feature

## Step 2: Apply INVEST Criteria

Each story must be:
- **I**ndependent — can be developed without depending on another story
- **N**egotiable — the how is flexible; only the what is fixed
- **V**aluable — delivers value to an actor; not a purely technical task
- **E**stimable — the team can size it (if not, split it)
- **S**mall — completable in one sprint; if not, split
- **T**estable — has acceptance criteria; if you can't test it, rewrite it

If a story fails INVEST, apply splitting patterns (Step 4).

## Step 3: Write Acceptance Criteria (Gherkin)

```gherkin
Given <precondition / context>
When  <actor action>
Then  <observable system outcome>
```

Minimum: 1 happy path + 1 failure path per story.

## Step 4: Story Splitting Patterns

| Pattern | When to use | Example |
|---|---|---|
| By workflow step | Story covers a multi-step process | Split "Submit and approve claim" → "Submit claim" + "Approve claim" |
| By data variation | Story handles multiple data types | Split by file format: CSV vs XML |
| By user role | Story applies to multiple roles differently | Admin view vs user view |
| By CRUD operation | Story covers full CRUD | Split Create / Read / Update / Delete |
| By happy/unhappy path | Story covers success + failure | Split into separate stories |
| Spike | Story is not yet estimable | Add a timebox spike story first |

## Step 5: Create in Jira (via Atlassian MCP)

Use `mcp__claude_ai_Atlassian__createJiraIssue` with:
- issueTypeName: Story
- summary: the Connextra first line
- description: full story body with acceptance criteria
- additional_fields: priority, labels, epic link

## Quality Gate

- [ ] Connextra format: As a / I want / So that
- [ ] Passes all 6 INVEST criteria
- [ ] ≥ 2 acceptance criteria (happy + failure)
- [ ] MoSCoW priority assigned
- [ ] Story is ≤ 8 story points (or split if larger)
- [ ] Created in Jira with epic link
