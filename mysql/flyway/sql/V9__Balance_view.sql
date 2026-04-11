-- Derived balance from ledger (use with application reconciliation jobs)
CREATE OR REPLACE VIEW v_account_balance_from_ledger AS
SELECT
    account_id,
    COALESCE(SUM(credit_minor - debit_minor), 0) AS balance_minor_derived
FROM ledger_entries
GROUP BY account_id;
