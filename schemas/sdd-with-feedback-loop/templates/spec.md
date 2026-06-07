## ADDED Requirements

This document details *changes* to requirements and is additive to the `design.md` document, not a replacement.

### Requirement: ADDED [capability requirement title]

The system SHALL <expected behavior>.

#### Scenario: [happy path]

- **Given** <initial context>
- **When** <action>
- **Then** <observable and measurable result>

#### Scenario: [edge/failure path]

- **Given** <initial context>
- **When** <action>
- **Then** <observable and measurable result>

## MODIFIED Requirements

### Requirement: MODIFIED [existing requirement title]

The system SHALL <updated behavior>.

#### Scenario: [changed behavior]

- **Given** <initial context>
- **When** <action>
- **Then** <observable and measurable result>

## REMOVED Requirements

### Requirement: REMOVED [removed requirement title]

Reason for removal:

## Traceability

- Proposal element -> Requirement:
- Design decision -> Requirement:
- Requirement -> Task(s):

## Non-Functional Acceptance Criteria

> **Important:** NFAC scenarios MUST NOT duplicate scenarios already expressed in the functional requirements sections above (ADDED/MODIFIED/REMOVED). If a functional scenario already covers a given behavior (e.g., access-control rejection, error handling), cross-reference it here instead of repeating it. Only include NFAC scenarios that express genuinely new, non-functional behaviors (latency budgets, throughput limits, recovery SLOs, audit logging, etc.).

### Requirement: Performance

#### Scenario: Latency budget

- **Given** <load/profile>
- **When** <operation>
- **Then** <target metric>

### Requirement: Security

> If access-control rejections are already fully specified by functional scenarios above, replace the scenario below with a cross-reference: "See functional scenarios: [scenario name(s)]". Only add a distinct scenario here if there is a security property not expressed by the functional requirements (e.g., audit log written, token not leaked in error body).

#### Scenario: Access control

- **Given** <actor>
- **When** <action>
- **Then** <expected control/denial>

### Requirement: Reliability

#### Scenario: Recovery behavior

- **Given** <fault condition>
- **When** <retry/recovery step>
- **Then** <expected outcome>
