/* =====================================================================
   SIGEA - 90_reset_lab.sql

   Restores the synthetic data to its baseline after a lab session. The
   SIGEA labs (DOTNET-SQLI-01 read-only search, DOTNET-IDOR-01 read-only
   transcript access) do not modify data, so this is normally a no-op; it is
   provided to guarantee a clean, reproducible baseline. Re-applies the full
   synthetic dataset. RUN AS A USER WITH DML ON THE SIGEA SCHEMA.
   ===================================================================== */
:r 02_synthetic_data.sql
-- If :r is unavailable (non-sqlcmd), simply re-run db/data/02_synthetic_data.sql.
