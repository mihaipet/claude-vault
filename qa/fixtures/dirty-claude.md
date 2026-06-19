# Storefront API

Backend service for the customer-facing storefront. Handles product catalogue, cart, and checkout.

---

## Rules

- Never return internal database IDs in API responses — use slugs or UUIDs only
- All endpoints must validate input with Zod before touching the database
- If a function is over 40 lines, it needs to be split — no exceptions

## Tech stack

- Node 20 + TypeScript 5
- Fastify for the HTTP layer (not Express)
- Drizzle ORM with PostgreSQL
- Vitest for unit tests, Supertest for integration tests

## General

Always respond in the language the user writes in.
