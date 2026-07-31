---
name: backend-api-contracts
description: Designs and changes stable, verifiable, observable, and backward-compatible backend APIs. Use when working on endpoints, request/response schemas, HTTP status codes, validation, pagination, authentication, multi-tenancy, webhooks, queue consumers, retries, or API integrations.
---

# Backend API Contracts

## Contract Design

- Define request/response schemas, field names, types, nullability rules, and timestamp semantics explicitly.
- Keep input/output data types, serialization, encoding, API behavior, and configuration meaning consistent. Avoid silent contract drift, hidden type conversion, and implicit behavior changes.
- HTTP methods and status codes must match their semantics. Success and failure responses must not use an ambiguous shared format; errors must include an identifiable `error code` or `error type`.
- Validate input at the boundary layer instead of delegating all validation to downstream services or the database. Do not expose internal exceptions, credentials, or sensitive payloads directly to clients.
- Keep pagination, sorting, and filtering semantics stable and documented. Prefer backward-compatible additions to avoid breaking existing clients.

## Reliability and Data Isolation

- Consider idempotency, deduplication, and duplicate-submission risks for every write operation that may be retried.
- Confirm authorization boundaries, tenant isolation, data-access scope, and webhook/callback deduplication.
- Define timeout, retry, rate-limit, fallback, and failure-state behavior explicitly. Do not let implicit retries or fallbacks change the contract.
- Plan migrations, schema changes, and API contract changes separately; validate compatibility before deployment.

## Observability

Use a request ID or trace ID to make failures traceable. Logs should contain enough information to diagnose failures without exposing complete API keys, access tokens, sessions, passwords, personal data, credentials, or large sensitive payloads.

## Pre- and Post-change Checks

Before a change, inventory existing clients, batch jobs, webhooks, queue consumers, third-party integrations, and database state. After the change, use schema/contract tests, integration tests, actual API responses, and error-path tests to verify:

1. Request/response formats and types have not drifted implicitly.
2. Status codes, error codes/types, validation, and timestamp semantics remain consistent.
3. Retry, resubmission, authorization, and tenant-isolation behavior is correct.
4. Existing consumers remain compatible, and failures can be traced through request/trace IDs.
