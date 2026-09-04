# TDD for ICs

You are an IC under an orchestrator. Your brief names your TASK, SCOPE, ACCEPTANCE, and SEAMS; your tests are part of the deliverable; a separate reviewer will re-run your acceptance commands and attack your tests against this doctrine. There is no user to ask — the brief is the agreement, and your REPORT is the reply.

TDD is the red → green loop: write the failing test first, then only enough code to pass it. Every section here applies on every cycle.

## Rules of the loop

- **Red before green.** Write the failing test, watch it fail, then write the minimal code that passes. Don't anticipate future tests or add speculative features.
- **Vertical slices.** One seam, one test, one minimal implementation per cycle — each test a tracer bullet that responds to what the last cycle taught you. Never all-tests-then-all-code (horizontal slicing): bulk-written tests verify imagined behavior, test the shape of things rather than real behavior, and commit you to test structure before the implementation has taught you anything.
- **Refactoring is not part of the loop.** Green code that wants restructuring is a note in CONCERNS, not a detour: the orchestrator queues refactors as their own tasks.
- If the repo has a `CONTEXT.md` or ADRs covering your SCOPE, read them first so test names and interface vocabulary match the project's domain language.

## Seams — where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

Your brief's SEAMS field is the pre-agreed list of seams under test. That agreement is how testing effort lands on critical paths and complex logic instead of every edge of everything — honor it: test the listed seams, and put any seam you believe is missing in CONCERNS rather than silently expanding coverage.

If a code brief arrives with SEAMS empty or "n/a", that is a brief defect, not a waiver: don't stall and don't skip tests. Pick the most defensible public interfaces in your SCOPE, test there, and flag the missing field in CONCERNS so the orchestrator fixes the brief.

## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification — "user can checkout with valid cart" tells you exactly what capability exists — and survives refactors because it doesn't care about internal structure.

```typescript
// GOOD: Tests observable behavior
test("user can checkout with valid cart", async () => {
  const cart = createCart();
  cart.add(product);
  const result = await checkout(cart, paymentMethod);
  expect(result.status).toBe("confirmed");
});
```

Characteristics: tests behavior callers care about; uses the public API only; survives internal refactors; describes WHAT, not HOW; one logical assertion per test.

## Anti-patterns — the reviewer hunts these

**Implementation-coupled** — mocks internal collaborators, tests private methods, asserts on call counts or order, or verifies through a side channel instead of the interface. The tell: the test breaks when you refactor but behavior hasn't changed.

```typescript
// BAD: Tests implementation details
test("checkout calls paymentService.process", async () => {
  const mockPayment = jest.mock(paymentService);
  await checkout(cart, payment);
  expect(mockPayment.process).toHaveBeenCalledWith(cart.total);
});

// BAD: Bypasses the interface to verify
test("createUser saves to database", async () => {
  await createUser({ name: "Alice" });
  const row = await db.query("SELECT * FROM users WHERE name = ?", ["Alice"]);
  expect(row).toBeDefined();
});

// GOOD: Verifies through the interface
test("createUser makes user retrievable", async () => {
  const user = await createUser({ name: "Alice" });
  const retrieved = await getUser(user.id);
  expect(retrieved.name).toBe("Alice");
});
```

**Tautological** — the assertion recomputes the expected value the way the code does, so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth: a known-good literal, a worked example, the spec.

```typescript
// BAD: Expected value is recomputed the way the code computes it
test("calculateTotal sums line items", () => {
  const items = [{ price: 10 }, { price: 5 }];
  const expected = items.reduce((sum, i) => sum + i.price, 0);
  expect(calculateTotal(items)).toBe(expected);
});

// GOOD: Expected value is an independent, known literal
test("calculateTotal sums line items", () => {
  expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);
});
```

**Happy-path-only** — ACCEPTANCE is semantic, not just exit-code-zero: the failure branch, empty/absent states, and error paths are part of the behavior. The reviewer will feed your code the inputs you didn't test; get there first.

## Mocking

Mock at **system boundaries** only: external APIs (payment, email), time/randomness, sometimes the database (prefer a test DB) and filesystem. Never mock your own classes, internal collaborators, or anything you control.

At those boundaries, design interfaces that are easy to mock:

**Dependency injection** — pass external dependencies in rather than creating them internally:

```typescript
// Easy to mock
function processPayment(order, paymentClient) {
  return paymentClient.charge(order.total);
}

// Hard to mock
function processPayment(order) {
  const client = new StripeClient(process.env.STRIPE_KEY);
  return client.charge(order.total);
}
```

**SDK-style interfaces over generic fetchers** — a specific function per external operation, so each mock returns one shape, test setup has no conditional logic, and it's obvious which endpoints a test exercises:

```typescript
// GOOD: Each function is independently mockable
const api = {
  getUser: (id) => fetch(`/users/${id}`),
  getOrders: (userId) => fetch(`/users/${userId}/orders`),
  createOrder: (data) => fetch("/orders", { method: "POST", body: data }),
};

// BAD: Mocking requires conditional logic inside the mock
const api = {
  fetch: (endpoint, options) => fetch(endpoint, options),
};
```