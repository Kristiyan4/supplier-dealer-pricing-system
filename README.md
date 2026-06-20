# Supplier–Dealer Pricing & Orders System

A relational database for managing suppliers, products, dealer clients, time-versioned pricing, orders, and product ratings. Built in MySQL 8.x (InnoDB), this project goes beyond basic CRUD and focuses on data integrity, concurrency-safe business logic, and historical price tracking.

## Schema overview

- **suppliers / dealer_clients** – the two sides of the trade relationship, each with their own contact info and (for dealers) a negotiated discount percentage
- **categories** – self-referencing table supporting parent/child category trees
- **products** – linked to a supplier and an optional category, with active-stock tracking enforced via a `CHECK` constraint
- **product_prices** – a temporal table: every price change creates a new row with a `valid_from` / `valid_to` window, so full price history is preserved. A generated column plus a unique key guarantees a product can only ever have one currently-active price at a time
- **orders / order_items** – orders placed by dealers, with line totals auto-calculated by triggers
- **product_views** – tracks which dealers viewed which products (basic analytics)
- **product_ratings / product_rating_stats** – dealer ratings per product, with aggregate stats kept in sync via triggers
- **price_change_log** – full audit trail of every price change, including who made it

## Business logic

- **`sp_create_order`** – validates stock and dealer status, applies the dealer's discount, locks the relevant rows with `SELECT ... FOR UPDATE`, and creates the order inside a transaction with proper rollback on error.
- **`sp_change_product_price`** – closes out the old price window and opens a new one atomically, logging the change.
- **`sp_top_selling_products`** – aggregates best-sellers over a date range using a temporary table.
- **`sp_annual_price_change_report`** – uses an explicit cursor to walk every active product and compute year-over-year price movement.
- **Triggers** keep `order_items.line_total`, `orders.total_amount`, and `product_rating_stats` automatically consistent on insert/update/delete, so the application layer never has to maintain derived totals manually.

## Views

- `v_current_product_prices` – live catalog with current price, stock, and rating
- `v_dealer_order_history` – full order history per dealer
- `v_product_rating_summary` – rating breakdown per product

## Demonstration queries

The script includes worked examples of every standard JOIN type (`INNER`, `LEFT`, `RIGHT`, `CROSS`, `SELF`, and an emulated `FULL OUTER JOIN` via `UNION`, since MySQL has no native support for it), subqueries, `GROUP BY` / `HAVING`, and calls to all stored procedures.

## Running it

```bash
mysql -u your_user -p < schema.sql
```

This creates the `supplier_dealer_system` database, all tables, indexes, procedures, triggers, views, and seeds it with sample data.

## Tech

MySQL 8.x · InnoDB · Stored procedures · Triggers · Transactions · Cursors · Generated columns · Views
