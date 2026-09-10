# Frontend architecture reference

Language- and framework-agnostic rules for client applications: web, mobile,
desktop.

**Provenance.** Derived from `~/Desarrollo/guidelines-frontend.md`. Same philosophy
as the backend reference - pure domain, dependencies pointing inward, convention
over configuration - moved to the client. The way of working (think first,
simplicity, surgical changes, verifiable goals, imitate the canonical example) lives
in `../SKILL.md` and is not repeated here.

---

## 1. Layers

Organise code **by feature**, and inside each feature by layer. The dependency rule
always points toward the domain.

| Layer | Contains | Forbidden |
|---|---|---|
| **Domain** | Entities, value objects, client-side business rules, repository interfaces | Any import of the UI framework, HTTP, storage or plugins |
| **Application** (state) | Use cases / actions, state management, immutable UI states | Network or storage details; knowledge of concrete widgets or components |
| **Infrastructure** | API clients, DTOs and mappings, local cache/storage, native plugin adapters | Business rules |
| **Presentation** | Screens, components, navigation, visual formatting | Business logic; direct API calls |

- The domain is **pure language code**: its tests start no framework, no network, no
  render.
- Presentation is **deliberately dumb**: it paints the state it receives and
  dispatches actions. If a component holds a business `if`, that `if` belongs to
  another layer.
- Wiring - dependency injection, providers, locators - is declared in the app's
  composition, not inside the classes: domain and application do not know how they
  are built.
- **One folder per feature**, with stable per-layer subfolders. Knowing the feature,
  you know where everything is.
- What is genuinely shared - design system, cross-cutting domain helpers - lives in
  an explicit and small `shared/` module. When in doubt, **duplicate before coupling
  two features**.

### Unidirectional data flow

- **Writes**: the UI dispatches an action or intent → the use case runs (validates,
  calls repositories) → state updates → the UI re-renders. The UI never mutates
  state directly.
- **Reads**: the UI consumes **immutable states already prepared for painting** -
  formatted data, loading flags, resolved messages. The component does not
  calculate, it presents.
- A screen's state is modelled as **closed, explicit types** (`initial / loading /
  loaded / error`), not as a bag of combinable booleans (`isLoading && !hasError &&
  data != null`). **Impossible states must not be representable.**

---

## 2. Client-side domain model

### Entities and value objects

- Immutable models, invariants validated at construction; optional values explicitly
  optional in the type.
- **No loose primitives in the domain**: typed ids (a `UserId` is not an `OrderId`
  even if both wrap a string) and wrapper types for attributes with rules - email,
  amount, delivery date.
- **Do not expose raw enums coming from the API**: wrap them in your own type that
  validates the received value and has a defined case for unknown values. The API
  will evolve before the installed app does.

### Repositories

- Interface in the domain, plural name (`Orders`, `Claims`); it exposes business
  operations, not HTTP verbs (`findPending()`, not `get('/orders?status=pending')`).
- The implementation lives in infrastructure and decides the strategy - network,
  cache, offline - without the domain or the UI knowing.

### Use cases / actions

- One use case = one business operation named with a verb (`SubmitClaim`,
  `RefreshOrders`). Dependencies by constructor (domain interfaces), no state of its
  own.
- The UI invokes use cases or dispatches actions; it **never calls repositories or
  API clients directly**.
- Idempotence and protection against the impatient user: a double tap, a resubmitted
  form or an action repeated during a loading state must not duplicate effects -
  disable, debounce, or check inside the use case.

---

## 3. The API boundary (anticorruption)

- **Never deserialise the API response straight into your domain model.** An
  explicit DTO with the shape of the contract, plus an explicit DTO → domain mapping
  in infrastructure. The backend evolves at another pace; the mapper is your shock
  absorber.
- The field-by-field mapping lives **next to the DTO** (one less place to look) and
  is the only point where the backend's shape is tolerated.
- **Tolerant on reads, strict on writes**: reading, an extra or unknown field does
  not break the app; writing, send exactly the agreed contract.
- Network and business errors are **domain types** (`SessionExpired`, `OutOfStock`,
  `NoConnection`), not HTTP codes or HTTP-client exceptions leaked upward.
  Infrastructure translates; the UI decides how to present.
- Everything asynchronous has **at least three states** - loading, success, error -
  and the UI represents all three. A spinner with no error state is a latent bug.

---

## 4. State

- **Local state by default**: a form's or a screen's state lives in that screen.
  Promote to shared or global state only when more than one feature genuinely
  consumes it - never "just in case".
- **One single source of truth per datum**: never copy the same datum into two
  stores and synchronise them by hand. **Derive, do not duplicate.**
- Global state (session, user, settings) is small, explicit and has a clear owner.
- **Cache is infrastructure**, not UI state: the freshness policy - TTL,
  invalidation, offline - lives behind the repository. The screen asks for data and
  does not know where it came from.
- **Navigation is an application-layer decision** - the result of an action or a
  state change - not a hidden effect inside a deep component.

---

## 5. Presentation

- **One component or screen = one UI use case.** Drawer-components with ten
  responsibilities get split.
- Components **pure with respect to their inputs**: same props or state, same
  render. Effects - analytics, navigation, snackbars - fire from state changes, at a
  single identifiable point.
- **Declarative validation at the edge**: forms validate locally with the same rules
  as the domain (reuse the value objects) and show the error next to the field. Do
  not rely on the backend's 400 to inform the user.
- Visible text always goes through the project's i18n system - never hardcoded
  strings in components - even when there is only one language today.
- **The design system rules**: tokens (colour, spacing, typography) and shared base
  components. No magic inline style values in screens.

---

## 6. Naming

| Thing | Pattern |
|---|---|
| Entity | `<X>` |
| Own id / referenced id | `<X>Id` / `<X><Other>Id` (distinct types) |
| Repository | plural: `<Xs>` |
| Use case / action | `<Verb><X>` |
| Screen state | `<Screen>State` (closed types: `Loading`, `Loaded`, `Error`) |
| DTO / mapper | `<X>Dto` / mapping next to the DTO |
| Screen / component | `<UiUseCase>Screen` / `<Thing><Role>` (`OrderCard`, `ClaimForm`) |
| Object mother / test builder | `<Class>Mother` |
| Folders | one per feature; stable layers inside |

**Test names describe behaviour** observable by the user or by the domain, in
whatever syntax the project already uses.

---

## 7. Testing

### Principles

- The test name describes **observable behaviour**, not implementation. Test "shows
  the error when the API fails", not "calls the fetch method".
- **Object mothers** centralised and reusable; **controlled randomness** through one
  project helper. Ad-hoc random generators are forbidden - scattered random data
  makes failures irreproducible.
- Do not test the framework (that a binding updates the view); test your logic and
  your integration.

### The pyramid

- **Unit**: domain, DTO↔domain mappers, use cases and state logic with doubles. This
  is the fat layer: if the domain is pure, they are trivial to write and extremely
  fast.
- **Component / widget**: the screen rendered with controlled state - every state
  (loading, error, empty, data) has its test. Doubles are injected through the same
  seams as in production.
- **Integration / end-to-end**: the real app navigating core flows with **the API
  always mocked** (mock server or network stubs). No test calls a real system.

### Rules for integration tests

- **Seed state through the app's own paths** - navigating, filling forms, with the
  mocked API responding - not by manipulating stores or storage underneath. If the
  state cannot be reached by using the app, the test is lying.
- **Given / When / Then** with reusable pieces (`*Given` seeds, `*When` acts,
  `*Validator` checks). Reuse them instead of hand-rolling setup.
- **Asynchronous flows never get immediate assertions**: wait for the UI to settle
  or poll with a timeout; never a fixed sleep.
- Tests **independent of order and of previous state**: each starts from a known
  state (reset mocks, storage and session). With shared resources, fixed ids and
  idempotent seeding.
- Cover end-to-end only the **core flows** (login, the main business transaction),
  not every screen: they are the most expensive tests to maintain.

### Definition of done

- Before calling a change done: run the unit **and** component tests **of the area
  affected** - not the whole suite, which is CI's job on the pull request - and
  verify the change in the running app. The real render always surprises.
- Then assess end-to-end coverage: if it touches a core flow, **propose** extending
  or adding an integration test. Propose it, do not add it by default.

---

## 8. Local data and contract versioning

*The client analogue of "schema first, code second".*

1. **Local storage has a schema and a version.** Every persisted structure - local
   database, preferences, serialised cache - carries a version and a migration, or
   an explicit discard policy, from every previous version: the updated app will
   start on top of old data.
2. **Backward compatibility with the API**: old versions of the app live in the
   stores for months. Before consuming a new field, confirm the backend deployed it.
   Backend first, client second.
3. Functionality that depends on a new contract, or that is risky, goes **behind a
   feature flag or remote config**, with the app working correctly while the flag is
   off.
4. Contract changes are followed **along the whole chain**: API → DTO → mapper →
   domain → state → screen. A field added that never reaches the UI, or reaches it
   unmapped, is half-finished work - ask how far the data must reach.

---

## 9. Configuration and releases

- **Per-environment configuration outside the code**: environments declared as
  builds or flavours, with URLs, keys and flags versioned and reviewable per
  environment. Switching environment is never editing a constant.
- No secrets in the repository nor embedded in the binary beyond the unavoidable -
  everything shipped to a client is public.
- Automate the release pipeline (build, signing, upload) with explicit guardrails:
  which branches produce which delivery, and which verification confirms that what
  shipped is what was expected.
- Observability from day one: crash reporting and error analytics connected before
  the first release. A frontend without telemetry fails silently in the user's
  pocket.

---

## Key ideas

1. The domain imports nothing from the UI framework; technical concerns plug in from
   outside.
2. Unidirectional flow: the UI dispatches actions and paints state; it never mutates
   or computes business rules.
3. Screen states as closed types: the impossible must not be representable.
4. DTO plus explicit mapper at the API boundary; never deserialise into the domain.
5. Errors are domain types, not HTTP codes leaked up to the UI.
6. Local state by default; global only with a clear owner and a real need. Derive, do
   not duplicate.
7. Everything asynchronous has loading, success and error - and the UI shows all
   three.
8. Tests seed through the app, mock all network, wait for asynchrony and control
   their randomness.
9. Backend first, client second; local storage versioned; the risky bits behind a
   flag.
10. Simplicity and surgical changes: the best code is the code you do not write.
