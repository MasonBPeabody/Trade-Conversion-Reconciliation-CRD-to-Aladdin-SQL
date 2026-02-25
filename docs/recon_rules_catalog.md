# Reconciliation Rules Catalog (CRD -> Aladdin)

## Purpose
Defines the reconciliation control checks, ownership, severity, and expected outputs. This catalog supports governance, testing discipline, and sign-off traceability.

## Rule Table
| Rule ID | Break Code | Category | Description | Severity | Owner | SQL Output |
|---|---|---|---|---|---|---|
| R001 | MISSING_IN_ALADDIN | Completeness | CRD trade not found in Aladdin by legacy_trade_id within conversion window | HIGH | Tech/Ops | recon_breaks |
| R002 | NO_LEGACY_ID | Completeness | Aladdin trade missing legacy_trade_id (non-deterministic conversion record) | MED | Tech | recon_breaks |
| R003 | DUP_LEGACY_ID | Completeness | Multiple Aladdin trades share the same legacy_trade_id | HIGH | Tech | recon_breaks |
| R004 | MAP_MISSING_ACCT | Mapping | CRD account_id not mapped to expected Aladdin account_id | HIGH | Data | recon_breaks |
| R005 | MAP_MISSING_SEC | Mapping | CRD security_id not mapped to expected Aladdin security_id | HIGH | Data | recon_breaks |
| R010 | MISMATCH_SIDE | Accuracy | Side mismatch after mapping and match | MED | Ops | recon_breaks |
| R011 | MISMATCH_QTY | Accuracy | Quantity mismatch after match | HIGH | Ops | recon_breaks |
| R012 | MISMATCH_PRICE | Accuracy | Price mismatch beyond tolerance | MED | Ops | recon_breaks |
| R013 | MISMATCH_GROSS | Accuracy | Gross amount mismatch beyond tolerance | MED | Ops | recon_breaks |
| R014 | MISMATCH_DATES | Accuracy | Trade date or settle date mismatch | LOW | Ops | recon_breaks |

## Evidence Requirements
HIGH severity breaks:
- root cause documented (mapping gap, extract defect, conversion logic defect, upstream replay, etc.)
- remediation action documented
- retest evidence (query output before/after) and sign-off note

MED severity breaks:
- documented rationale and remediation plan or tolerance waiver
- retest evidence where applicable

LOW severity breaks:
- documented explanation (expected differences or downstream scheduling) and closure note

## Exit Criteria for Sign-Off
- 0 OPEN HIGH severity breaks (or formally waived with approval)
- completeness exceptions reconciled to approved exclusions
- daily summary produced and validated for the sign-off date
