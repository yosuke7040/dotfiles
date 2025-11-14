# Principles

## Core

- Act without hesitation and give your utmost effort.
- Always think in English and respond in Japanese.
- To maximize efficiency, if multiple independent operations are required, call all relevant tools simultaneously rather than sequentially.
- Always use sub-agents to validate complex problems.
- After receiving tool results, carefully evaluate their quality and determine the optimal next step before proceeding. Use this new information to plan, iterate, and take the best possible action through deliberate reasoning.
- Split new files by functionality to maintain modularity (consider breaking them up if they exceed 500 lines).
- JavaScript modules: place one main class or function per file.
- CSS files: separate by component or feature (e.g., modal.css, sidebar.css, editor.css).
- Backend services: separate concerns (routes, middleware, database, workers).
- Recommended file size: aim for roughly 500–700 lines to keep code maintainable.
- After updating CLAUDE.md, translate it into Japanese and update CLAUDE_ja.md as well.

## Workflow Structure

- Follow the explore–plan–code–commit approach: understand → plan → implement → commit.
- Always read and understand existing code before making changes.
- Create a detailed plan before implementation.
- Use an iterative approach.
- Correct course early and frequently.

## Context Management

- Provide visual references.
- Include relevant background information and constraints.
- Update and maintain the CLAUDE.md file to preserve project context.
- Document project-specific patterns and rules.

## Design Documentation

- When using plan mode to design or determine requirements, output the work as ADRs (Architecture Decision Records) or design documents.
- Store all design documentation in the directory: `repository_root/.claude/doc/`.
- Ensure the documentation directory exists before creating documents.
- Use the naming format: `yyyymmdd_{documentName}.md` (e.g., `20250114_authentication_design.md`).

## Problem-Solving Approach

- Leverage reasoning abilities to perform complex, multi-step reasoning.
- Focus on understanding the problem requirements, not merely passing tests.
- Use test-driven development.

## Tool and Resource Optimization

- Optimize tool usage by making parallel calls to maximize efficiency.
- Use sub-agents to validate complex problems.

# SuperClaude Entry Point

@COMMANDS.md
@FLAGS.md
@PRINCIPLES.md
@RULES.md
@MCP.md
@PERSONAS.md
@ORCHESTRATOR.md
@MODES.md
