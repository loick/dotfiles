## Plan Mode

- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.

## Context7

Always use Context7 to get relevant documentation on a library before starting a new task.

## JSX Formatting

- Add a blank line between sibling components in JSX for readability:

```tsx
// Good
<Layout.Column>
  <ComponentA />

  <ComponentB />

  <ComponentC />
</Layout.Column>

// Avoid
<Layout.Column>
  <ComponentA />
  <ComponentB />
  <ComponentC />
</Layout.Column>
```

## Git

Never bypass CI. Precommit hooks must not be skipped, bypassed, removed, or modified.
