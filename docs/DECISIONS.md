# Architectural Decision Records (ADRs)

## Template for New Decisions

```markdown
# ADR-XXXX: [Title]

## Status
[Proposed | Accepted | Superseded by ADR-YYYY]

## Context
What is the issue that we're seeing that is motivating this decision or change?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult to do because of this change?
```

## Current Decisions

### ADR-0001: Use Azure Developer CLI for Infrastructure Deployment

**Status:** Accepted

**Context:** Need a consistent, reproducible way to deploy Azure infrastructure across environments.

**Decision:** Use Azure Developer CLI (azd) with Bicep templates for all infrastructure deployments.

**Consequences:**

- Pros: Consistent deployment process, environment isolation, easy cleanup
- Cons: Learning curve for azd-specific conventions

### ADR-0002: Organize Documentation in /docs Folder

**Status:** Accepted

**Context:** Need better organization of documentation files for maintainability and clarity.

**Decision:** Move all documentation files to a dedicated `/docs` folder with clear naming conventions.

**Consequences:**

- Pros: Better organization, easier navigation, cleaner root directory
- Cons: Need to update references and links

---

_Add new ADRs as architectural decisions are made during development._
