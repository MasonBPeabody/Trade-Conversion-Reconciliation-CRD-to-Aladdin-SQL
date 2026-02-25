# Trade-Conversion-Reconciliation Charles River to Blackrock Aladdin (SQL Base)
Migrated from Charles River to Blackrock Aladdin and provided trade completeness and accuracy across the conversion window.

SQL-based reconciliation framework for a trade migration from Charles River (CRD) to BlackRock Aladdin. Validates trade completeness and field-level accuracy across a defined conversion window, classifies breaks, and produces audit-ready exception reports and tie-outs for operations and controls.

# Trade Conversion Reconciliation (Charles River -> BlackRock Aladdin) | SQL Framework

## Purpose
This repository provides a SQL-based reconciliation framework to validate **trade completeness and field-level accuracy** during a Charles River (CRD) to BlackRock Aladdin migration. It is designed to support operational control requirements, conversion sign-off, and audit-ready documentation across a defined conversion window.

## Business Context
During OMS migrations, conversion risk typically falls into three categories:
1. **Completeness**: every eligible source trade exists in the target system
2. **Accuracy**: key economic and static attributes are converted correctly (within tolerances)
3. **Governance**: breaks are classified, owned, aged, and resolved under controlled sign-off

## Scope
- Object: Trades (extensible to allocations, confirms, and settlements)
- Window: configurable conversion dates (see `docs/conversion_scope.md`)
- Output: break tables, break reports, and summary tie-outs for stakeholders (FO/Ops/Tech)

## Architecture
**Inputs**
- CRD trades extract (source of record for conversion population)
- Aladdin trades extract (target population; includes `legacy_trade_id` when available)
- Mapping tables (accounts, securities) required to normalize identifiers

**Processing**
- Normalize CRD trades into expected Aladdin identifiers
- Run completeness checks and field-level accuracy checks
- Classify breaks using a break taxonomy aligned to ownership and severity

**Outputs**
- `recon_breaks`: audit-ready exception register
- `recon_daily_summary`: daily tie-out and break trending (dashboard-friendly)

## Reconciliation Controls
### Completeness Controls
- CRD trades missing in Aladdin by `legacy_trade_id`
- Aladdin trades missing `legacy_trade_id` (unexpected in a conversion)
- Duplicate mapping: multiple target trades per source trade

### Accuracy Controls (field-level)
- Account mapping mismatch
- Security mapping mismatch
- Side mismatch
- Quantity mismatch
- Price mismatch (tolerance-based)
- Gross amount mismatch (tolerance-based)
- Trade date / settle date mismatch

## How to Run (Postgres recommended)
1. Create schema:
   - run `sql/00_schema.sql`
2. Load sample data:
   - run `sql/01_load_sample_data.sql`
3. Run recon + populate breaks:
   - run `sql/02_recon_checks.sql`
4. Generate reports:
   - run `sql/03_reports.sql`

## Deliverables Produced
- Exception register with severity, owner, and traceable details (`recon_breaks`)
- Daily tie-out / trending summary (`recon_daily_summary`)
- Rules catalog and mapping specification pack (`docs/`)

## Extension Roadmap
- Allocation reconciliation: EMS executions vs OMS allocations
- Settlement reconciliation: OMS vs custodian/prime
- Data warehouse tie-outs: curated layer vs source extracts
- Automated export for Power BI / Tableau dashboards

## Disclaimer
This repository uses synthetic/sample data structures to demonstrate conversion reconciliation patterns without exposing proprietary information.

# Conversion Scope and Assumptions (CRD -> Aladdin)

**2) docs/conversion_scope.md**

## Conversion Window
- Start Date: 2026-01-01
- End Date: 2026-01-31
- Eligibility: trades with `trade_date` within window and status in the conversion population (e.g., CONFIRMED / ALLOCATED depending on operating model)

## In-Scope Trade Populations
- Primary: executed trades captured in CRD and expected to exist in Aladdin post-cutover
- Exclusions (typical):
  - cancelled trades (if not migrated)
  - test trades
  - corrected/amended trades handled via post-conversion replay

## Keys and Matching Strategy
Primary matching key:
- `aladdin_trades.legacy_trade_id = crd_trades.crd_trade_id`

Fallback match (optional enhancement):
- economic fingerprint match on (trade_date, account, security, side, quantity, price)

## Tolerances
- Price tolerance: 0.0001
- Gross amount tolerance: 1.00 (currency units)
- Quantity tolerance: exact match (unless product requires rounding rules)

## Sign-off Criteria (example)
- Completeness: 100% of eligible CRD trades present in Aladdin (or documented exceptions)
- Accuracy: 99.5%+ field-level match rate on key economics (qty/price/gross) or documented breaks
- Governance: all HIGH breaks resolved or waived with approval and evidence

**- 3) docs/field_mapping.md**

# Field Mapping Specification (CRD -> Aladdin)

## Identifier Normalization
| Domain | CRD Field | Aladdin Field | Notes |
|---|---|---|---|
| Trade Key | crd_trade_id | legacy_trade_id | Expected primary match |
| Account | account_id | account_id | Requires `account_map` |
| Security | security_id | security_id | Requires `security_map` |

## Economic Fields
| Domain | CRD Field | Aladdin Field | Tolerance/Rule |
|---|---|---|---|
| Side | side | side | exact |
| Quantity | quantity | quantity | exact |
| Price | price | price | abs(diff) <= price_tol |
| Gross Amount | gross_amount | gross_amount | abs(diff) <= gross_tol |
| Currency | currency | currency | exact |
| Trade Date | trade_date | trade_date | exact |
| Settle Date | settle_date | settle_date | exact |

## Notes
- If Aladdin stores derived gross or rounded price differently, prefer recon on canonical economics (qty * price) and document rounding conventions.

**4) docs/recon_rules_catalog.md**

# Reconciliation Rules Catalog

| Rule ID | Category | Description | Severity | Owner | Output |
|---|---|---|---|---|---|
| R001 | Completeness | CRD trades missing in Aladdin (legacy id match) | HIGH | Tech/Ops | recon_breaks |
| R002 | Completeness | Aladdin trades missing legacy_trade_id | MED | Tech | recon_breaks |
| R003 | Completeness | Duplicate legacy_trade_id in Aladdin | HIGH | Tech | recon_breaks |
| R004 | Mapping | Missing account mapping for CRD account_id | HIGH | Data | recon_breaks |
| R005 | Mapping | Missing security mapping for CRD security_id | HIGH | Data | recon_breaks |
| R010 | Accuracy | Quantity mismatch | HIGH | Ops | recon_breaks |
| R011 | Accuracy | Price mismatch beyond tolerance | MED | Ops | recon_breaks |
| R012 | Accuracy | Gross amount mismatch beyond tolerance | MED | Ops | recon_breaks |
| R013 | Accuracy | Trade/settle date mismatch | LOW | Ops | recon_breaks |

## Evidence Expectations
- For HIGH breaks: root cause + remediation action + sign-off note
- For waived breaks: documented approval and rationale


