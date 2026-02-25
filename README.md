# Trade Conversion Reconciliation (CRD -> Aladdin) | Postgres SQL

## Overview
SQL-based reconciliation framework to validate trade completeness and field-level accuracy during a Charles River (CRD) to BlackRock Aladdin conversion. Produces an audit-ready exception register, break taxonomy, and dashboard-friendly summaries for controlled migration sign-off.

## Core Outputs
- recon_breaks: exception register with severity, ownership, and traceable details
- recon_daily_summary: daily trending and tie-out summary
- views: open breaks aging + break summary for BI

## Repo Structure
- sql/: schema, loads, recon checks, reports, views
- docs/: conversion scope, mapping spec, rules catalog
- data/: sample CSVs (optional)

## How to Run (Postgres)
Run in this order:
1) sql/00_schema.sql
2) sql/01_load_sample_data.sql
3) sql/02_recon_checks.sql
4) sql/03_reports.sql
5) sql/04_views.sql

## Documentation
- docs/conversion_scope.md
- docs/field_mapping.md
- docs/recon_rules_catalog.md

## Notes
Uses synthetic/sample data structures to demonstrate OMS conversion reconciliation patterns without exposing proprietary information.


