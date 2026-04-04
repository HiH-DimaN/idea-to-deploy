# Review Checklist

## Architecture Document

### Database Schema
- [ ] Every table has a name
- [ ] Every table has ALL fields listed with data types
- [ ] Primary keys defined for every table
- [ ] Foreign keys and relationships described
- [ ] Indexes mentioned for frequently queried fields
- [ ] No orphan tables (every table is used by at least one endpoint)

### API Endpoints
- [ ] Every endpoint has: HTTP method, path, description
- [ ] Request body format defined (with field types)
- [ ] Response format defined (with field types)
- [ ] Error responses documented (400, 401, 403, 404, 500)
- [ ] Authentication requirements specified per endpoint
- [ ] No orphan endpoints (every endpoint maps to a user story)

### Auth Flow
- [ ] Registration flow described step by step
- [ ] Login flow described step by step
- [ ] Token type specified (JWT, session, OAuth)
- [ ] Token refresh mechanism described
- [ ] Password reset flow described
- [ ] Role-based access defined (if applicable)

### Infrastructure
- [ ] Docker configuration described
- [ ] Environment variables listed
- [ ] External services/APIs listed with purpose
- [ ] Deployment target specified

## PRD Document

### User Stories
- [ ] Each story follows format: "As [role], I want [action], so that [benefit]"
- [ ] Priority assigned (P0/P1/P2) to every story
- [ ] Acceptance criteria defined for P0 stories
- [ ] Kill criteria defined (what would make the project fail)

### Requirements Traceability
- [ ] Every P0 story has at least one API endpoint in architecture
- [ ] Every P0 story has a step in implementation plan
- [ ] No conflicting requirements between stories

## Implementation Plan

### Step Quality
- [ ] Each step has a clear deliverable
- [ ] Each step lists specific files to create/modify
- [ ] Each step has verification commands (tests, curl, etc.)
- [ ] Steps are in correct dependency order
- [ ] No circular dependencies between steps
- [ ] Time estimates are provided and realistic

### Coverage
- [ ] All P0 user stories are covered by at least one step
- [ ] Database setup happens before any CRUD operations
- [ ] Auth setup happens before protected endpoints
- [ ] Tests are written alongside features (not all at the end)

## CLAUDE_CODE_GUIDE

### Prompt Quality
- [ ] Each prompt starts with "Read CLAUDE.md"
- [ ] Each prompt references specific architecture sections
- [ ] Each prompt lists concrete file names and paths
- [ ] Each prompt includes specific values (table names, field types, endpoints)
- [ ] Each prompt ends with verification commands
- [ ] After-block instructions include: update CLAUDE.md status, commit

## Cross-Document Consistency

### Naming
- [ ] Entity names are identical across all documents
- [ ] API paths use consistent naming convention
- [ ] Database table names match model names in code

### Tech Stack
- [ ] Same language/framework mentioned across all documents
- [ ] Same database mentioned across all documents
- [ ] Same deployment target across all documents
- [ ] Package versions are consistent

## Code (if exists)

### Structure
- [ ] Folder structure matches architecture document
- [ ] All models from architecture are implemented
- [ ] All endpoints from architecture are implemented
- [ ] Environment variables match .env.example

### Quality
- [ ] No hardcoded secrets or credentials
- [ ] No TODO/FIXME without issue reference
- [ ] Error handling exists for external calls
- [ ] Input validation on all endpoints
- [ ] Tests exist for P0 user stories

## Scoring Guide

| Score | Meaning |
|-------|---------|
| 9-10  | Production ready, all checks pass |
| 7-8   | Good, minor issues only |
| 5-6   | Usable but has gaps that need attention |
| 3-4   | Significant issues, not ready for implementation |
| 1-2   | Major problems, needs substantial rework |
