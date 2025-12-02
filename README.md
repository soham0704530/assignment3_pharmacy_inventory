
# Assignment 3 — Pharmacy & Inventory Analytics

## What’s in this repo
- SQL/assignment3_queries.sql — All SQL queries with descriptions.
- notebook/assignment3_analysis.ipynb — Notebook to run queries and produce outputs (paste notebook cells provided).
- outputs/ — where CSVs, charts and intermediate outputs will be stored after running the notebook.
- docs/report_summary.md — Executive summary, insights, recommendations.
- docs/project_writeups.md — Two 200–300 word live project descriptions.
- README.md — this file.

## How to run
1. Ensure you have a Postgres DB with the data loaded. If not, load CSVs into tables: Medicine, Supplier, Purchase_Stock, Pharmacy_Sale, Pharmacy_Sale_Item.
2. Set environment variables or edit the notebook connection variables:
   - DB_USER, DB_PASS, DB_HOST, DB_PORT, DB_NAME
3. (Optional) Create indexes for performance (see suggestions in the assignment instructions).
4. Open the Jupyter notebook and run cells in order. The notebook reads SQL from `SQL/assignment3_queries.sql` and writes CSV outputs to `outputs/`.
5. Inspect `outputs/` for the result CSVs and `outputs/*.png` for charts.

## Notes & assumptions
- The notebook expects PostgreSQL and SQL uses Postgres date functions. Adjust date syntax if using MySQL or SQLite.
- Replace :start_date and :end_date placeholders in the SQL or pass them via the notebook params.
- If many sale items lack batch matches, consider fallback pricing (latest purchase price) and document this assumption.

## Deliverables to submit
- `assignment3_queries.sql` (with inline 2–3 line explanations).  
- `assignment3_analysis.ipynb` (or Python script) that runs queries and saves CSV outputs.  
- `outputs/` CSVs and charts.  
- `docs/report_summary.md` and `docs/project_writeups.md`.  
- Zip the repo or share a GitHub link.

