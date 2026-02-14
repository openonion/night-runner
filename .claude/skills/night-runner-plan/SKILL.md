---
name: night-runner-plan
description: Create implementation plan for a GitHub issue
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(gh *)
argument-hint: [issue-number]
---

# Create Implementation Plan

You are analyzing a GitHub issue to create an implementation plan.

## Step 1: Get Issue Details

First, run this command to get issue details:
```bash
gh issue view $ARGUMENTS --json title,body
```

Also check if there's a previous plan by looking at comments:
```bash
gh issue view $ARGUMENTS --comments
```

If a previous plan exists (marked with `<!-- NIGHT_RUNNER_PLAN -->`):
- Review it to understand what was already considered
- Address any feedback in the comment thread
- Improve upon the previous plan if needed

## Step 2: Research & Read Code

BEFORE writing the plan, you MUST:

1. **Find all related files**
   - Use Glob to find relevant files by pattern
   - Use Grep to search for related code/imports
   - Look for existing similar implementations

2. **Read the actual code**
   - Read the files you'll need to modify
   - Read related files to understand patterns
   - Read tests to understand expected behavior
   - Understand the existing architecture

3. **Understand the context**
   - How does this feature fit into the codebase?
   - What patterns/conventions are used?
   - Are there similar features to reference?

DO NOT guess file contents. DO NOT assume code structure. READ FIRST.

## Step 3: Create Plan with Visual Diagrams

Your plan MUST include:

### 1. Workflow Diagram

Use ASCII art to show the lifecycle/flow:

```
Example for adding a feature:

User Request
     │
     ▼
┌─────────────┐
│ Entry Point │ ← Where user calls this
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Validation  │ ← What checks happen
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Core Logic  │ ← Main processing
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Output    │ ← What gets returned
└─────────────┘
```

### 2. File Structure Diagram

Show which files change and how they relate:

```
Example:

connectonion/
├── core/
│   ├── llm.py          ← Add OpenRouterLLM class
│   └── __init__.py     ← Export new class
├── utils/
│   └── routing.py      ← Update create_llm() routing
tests/
└── real_api/
    └── test_openrouter.py  ← New test file
```

### 3. Class/Function Relationships

If adding classes or functions, show relationships:

```
Example:

        LLM (base class)
          ▲
          │ inherits
          │
    OpenRouterLLM
          │
          ├─ __init__(model, api_key)
          ├─ complete(messages) → str
          └─ structured_complete(schema) → dict
```

### 4. Data Flow

Show how data moves through the system:

```
Example:

Input: "or/claude-3.5-sonnet"
   │
   ▼ create_llm()
Strip prefix → "claude-3.5-sonnet"
   │
   ▼ OpenRouterLLM.__init__()
Set base_url → "https://openrouter.ai/api/v1"
   │
   ▼ OpenRouterLLM.complete()
API call → OpenRouter
   │
   ▼
Return response
```

## Output Format

```markdown
## 🔍 Summary

[2-3 sentences: What needs to be done and why]

## 📊 Workflow

[ASCII diagram showing the lifecycle/flow]

## 📁 Files to Change

[Diagram showing file structure with annotations]

## 🏗️ Architecture

[Diagram showing class/function relationships if applicable]

## 🔄 Data Flow

[Diagram showing how data moves through the system]

## 📝 Implementation Steps

1. **Step name**
   - Concrete action
   - Specific file/line if known
   - Expected outcome

2. **Step name**
   - ...

## ⚠️ Risks & Considerations

- Potential issue 1
- Potential issue 2

## 🧪 Testing Strategy

- What to test
- How to verify it works
```

## Guidelines

- Use diagrams for EVERY plan
- Keep diagrams simple but informative
- Read actual code before planning
- Be specific about files and functions
- Don't over-engineer
- Focus on minimal change

## Output

Output ONLY the plan in markdown format, no other text.
