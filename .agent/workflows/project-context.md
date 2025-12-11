---
description: Read project context at conversation start - use /project-context
---

# Project Context Initialization

At the start of each conversation, read the project README for architecture context:

1. Read `/README.md` to understand the project structure, key components, and conventions.

## When to Update README.md

Update the README when any of these breaking changes occur:

- New major components/views are added
- Architecture changes (e.g., new persistence layer, new sync mechanism)
- New Core Data entities are added to the model
- Testing conventions change
- App Intents or system integration changes
- Key file locations or responsibilities change

## Update Guidelines

When updating, preserve the existing structure:
- **Architecture at a Glance** - Core components and their responsibilities
- **Running the App** - Setup and run instructions
- **Key Behaviors** - User-facing features
- **Testing Notes** - Test strategies and seeding
- **Tips for Contributors/AI Agents** - Important patterns and conventions
