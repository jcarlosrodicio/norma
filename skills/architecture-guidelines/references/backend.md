# Backend architecture reference

Language- and framework-agnostic rules for services, APIs, CLIs and workers.

**Provenance.** Derived from `~/Desarrollo/guidelines-arquitectura-clean-code.md`,
distilled from a real hexagonal + DDD backend. That original also carries a full
CQRS and event-driven doctrine - command/query buses, commands and handlers, domain
events, process managers, public events with hand-written mappers, transactional
outbox. **Those sections were deliberately removed here**: none of the projects this
harness serves uses buses or a broker, and prescribing them would push agents to
invent infrastructure that the simplicity rule forbids. If a project genuinely
becomes transactional and event-driven, take that doctrine from the original file
rather than improvising it.

The way of working (think first, simplicity, surgical changes, verifiable goals,
imitate the canonical example) lives in `../SKILL.md` and is not repeated here.

---

## 1. Structure and layers

### Bounded contexts

- Organise the repository in **bounded contexts**: autonomous business units with
  their own model, their own data schema and their own public contracts.
- **The same rules apply to every context.** Exceptions are documented explicitly
  where they occur, with their reason, and are not extended by analogy.

### Layers (dependencies point inward, toward the domain)

| Layer | Contains | Forbidden |
|---|---|---|
| **Domain** | Aggregates, value objects, business rules, repository interfaces | Any framework, ORM, HTTP, messaging |
| **Application** | Use cases, ports, orchestration of multi-step work | Concrete persistence or transport; business rules that belong to an aggregate |
| **Reads** | Queries, read models, projection DTOs | Business logic |
| **Infrastructure** | Persistence, repository adapters, external clients, dependency wiring | Business rules |
| **Delivery** | Endpoints/commands, startup, migration resources | Logic: it translates and delegates |

- The domain is **pure language code** (plus, at most, a declarative validation
  library). A domain test must not need to start anything.
- Wiring - bean registration, dependency injection, service locators - lives in
  infrastructure, never in the domain: domain classes carry no framework
  annotations.
- **One folder per aggregate** inside each layer, with stable subfolders. The
  structure is predictable: knowing the aggregate, you know where everything is.
- Where a dependency linter exists, the layer rule is whatever the linter enforces.
  Add the rule to the linter instead of only writing it down.

---

## 2. Tactical DDD

### Aggregates

- Closed to extension, fields private and immutable, invariants validated at
  construction: required values non-null, optional values explicitly optional in the
  type.
- **A named static constructor per use case** (`open`, `close`, `report`). Creating
  an aggregate through a named intent, not a bag of setters, is what keeps the
  invariants in one place.
- The full constructor - every field - is reserved for reconstruction from
  persistence.
- Accessors are not getters in the DTO sense: the aggregate is not a data holder.
  Equality and representation are explicit.

### Value objects everywhere

- **No loose primitives in the domain.** The aggregate's own id is a type; the ids
  of referenced aggregates are different types, distinguishable from each other and
  from it.
- **Do not expose language enums** in domain contracts: wrap them in a value object
  that validates the incoming value and exposes factory constants. The enum is an
  internal detail; the value object is the contract.
- Simple attributes - timestamps, amounts, references - become trivial wrapper types
  with validation.

### Use cases

- One use case = one business operation, named with a verb. Dependencies by
  constructor (domain interfaces), no state of its own.
- Messages that cross a boundary carry **primitives only** - ids, strings, numbers.
  Conversion to value objects happens inside, not before.
- **Idempotence where it applies**: check existence before creating; repeating the
  same operation must not duplicate effects.

### Repositories

- Interface in the domain, **plural name** (`Parcels`, `Claims`): it reads as the
  collection it represents.
- It exposes business operations, not storage verbs. Inherit shared CRUD from a
  base; declare only the extra methods that aggregate needs.
- The implementation lives in infrastructure and delegates mapping to the
  persistence entity.

---

## 3. Read models

- Reads do not have to go through the domain model. A read model queries the store
  directly and returns exactly the shape its consumer needs.
- **Query** named by its shape: `View<X>By<Y>`; its result is typically optional.
- **Read model** = flat, immutable DTO defined in the read layer, with the exact
  shape the client consumes.
- **View** = interface with a single `ask(...)` method; the implementation in
  infrastructure queries the store with SQL or a native query that maps 1:1 to the
  read model. Optimise it freely - there is no domain model to respect.
- This is a pattern, not an obligation. A project whose reads are already thin
  application queries does not need to introduce a separate read layer to satisfy
  this section.

---

## 4. Infrastructure and external contracts

### Persistence

- The persistence entity is separate from the aggregate; the `fromDomain` /
  `toDomain` mapping lives **in the entity itself**, not in a separate mapper class.
  One less place to look.
- Tables and columns in `snake_case`; tables plural. Audit columns (`created_at` and
  friends) are automatic and not editable by hand.

### The anticorruption boundary

- **Never deserialise an external response straight into your domain model.** An
  explicit DTO with the shape of the contract, plus an explicit field-by-field
  mapping to the domain, in infrastructure. The other side evolves at its own pace;
  the mapper is your shock absorber.
- What you publish outward is a decision, not a side effect: an explicit output
  contract mapped by hand from the internal model. You can then evolve the internal
  model without breaking consumers, and the reverse.
- **Follow the whole chain when you add a field**: aggregate → internal model →
  published contract (and its mapper) → downstream consumers. Downstream schemas
  usually drop undeclared fields *silently*; propagate the change to every link and
  ask the business how far the data must actually reach.
- If downstream consumers have a deployment order, respect it: deploying in reverse
  fails.

---

## 5. Delivery surface

- **One endpoint (or one CLI command) = one use case = one handler.** Its name is
  the name of the use case. No drawer-controllers with ten routes.
- The request is an immutable type local to the handler, with **declarative
  validation at the edge**.
- The handler validates, delegates and translates the response. Nothing else.
- **Protocol uniformity over purism**: choose a convention - response codes, verbs,
  the empty-result answer - and apply it without exceptions.

---

## 6. Naming

| Thing | Pattern |
|---|---|
| Aggregate | `<X>` |
| Own id / referenced id | `<X>Id` / `<X><Other>Id` (distinct types) |
| Repository | plural: `<Xs>` |
| Use case | `<Verb><X>` |
| Query / handler | `View<X>By<Y>` / `View<X>By<Y>Handler` |
| DTO / mapper | `<X>Dto` / mapping next to the DTO |
| Endpoint or command handler | `<UseCase>Controller` / `<UseCase>Command` |
| View implementation | `<Technology><ViewName>` |
| Object mother | `<Class>Mother` |
| Table / column | snake_case plural / snake_case |
| Migration | `<timestamp>.<ticket>.<engine>.sql` |

**Test names describe behaviour**, not implementation: `should_<behaviour>` with
`_when_<condition>` where a condition matters. Adopt the *rule*, not the literal
casing - in a project that already uses `describe`/`it`, keep that syntax and make
the sentence describe the behaviour.

---

## 7. Testing

### Principles

- The test name describes **behaviour**, not implementation.
- **Object mothers** centralised and reused across modules: a non-instantiable
  class, a main `random()` method, named variants as needed.
- **Controlled randomness**: all randomness in tests goes through one project
  helper (`randomInstant()`, `randomElement(...)`). Ad-hoc random generators are
  forbidden - scattered random data makes failures irreproducible.

### The pyramid

- **Unit**: domain and use cases with doubles; parameterised for null validation and
  multi-case rules.
- **Integration**: persistence adapters and views against the real database in a
  container, not against an in-memory fake.
- **Black box (service end-to-end)**: the real application started with its
  dependencies in containers and external services behind an HTTP mock.

### Rules for black-box tests

- **Seed state through the application's own paths** - its operations, its events,
  its endpoints - never by writing to the database directly. If the state cannot be
  created through the app, the test is lying.
- **Given / When / Then** with reusable pieces (`*Given` seeds, `*When` triggers,
  `*Validator` checks). Reuse them instead of hand-rolling setup.
- **External services are always mocked.** No test calls a real system.
- **Asynchronous flows never get immediate assertions**: poll with a timeout, never
  a fixed sleep.
- **One application context for the whole suite**: configuration overrides are
  global to the source set, not per test. Fragmenting the context breaks fixed-port
  resources and blows up run times.
- With concurrent execution and shared resources: protect mutable state with
  resource locks, and use fixed ids plus idempotent seeding for shared data.

### Definition of done

- Before calling a change done: run the unit **and** integration tests **of the area
  affected** - not the whole suite, which is CI's job on the pull request.
- Then assess end-to-end coverage of the change: if it touches a core flow,
  **propose** extending or adding a black-box test. Propose it, do not add it by
  default, and only for genuinely important behaviour.

---

## 8. Database migrations

1. The migration ships **in the same change** as the code that needs it, and it runs
   before that code does. (The original guideline demands a separate branch deployed
   ahead of the code; that is the right policy for a service with independent
   deployments and external consumers. For an application deployed as a whole, the
   same-change policy holds - see the project's adoption map for which applies.)
2. Schema versioning contains **DDL only**. Backfills (`UPDATE`) and seeds
   (`INSERT`) are run by hand against the database, never inside a migration.
3. **All DDL is idempotent** (`IF NOT EXISTS` / `IF EXISTS`). That lets you apply
   slow or blocking operations by hand and in advance - a concurrent index on a
   populated table - while the statement stays versioned in the repository: the
   deployment becomes a no-op instead of a failure.
4. Files carry a **chronologically ordered timestamp plus the ticket reference**;
   every changeset has a unique identifier and is registered explicitly at the end
   of the changelog.
5. Never let code reach a schema that does not exist. If you cannot guarantee the
   order, the change is not ready.

---

## 9. Configuration and deployment

- **Configuration lives outside the code**, per environment, versioned and
  reviewable. Switching environment is never editing a constant.
- No secrets in the repository.
- Static business data mapped in code - lookup tables, catalogues - has **one
  documented edit point** and validation against duplicates.
- Automate deployments with explicit guardrails: which branches may reach which
  environment, and which verification confirms the deployment was the expected one.

---

## Key ideas

1. The domain knows no framework; technical concerns are plugged in from outside.
2. Writes go through the model; reads may go straight to the store as flat models.
3. Primitives in messages, value objects inside the domain.
4. Explicit, hand-mapped external contracts; never publish the internal model.
5. One endpoint or command = one use case = one handler.
6. Convention over configuration: structure and names fully predictable - imitate
   the canonical example.
7. Tests seed through the app, wait for asynchrony and control their randomness.
8. Schema first, code second; DDL only, and idempotent.
9. Simplicity and surgical changes: the best code is the code you do not write.
