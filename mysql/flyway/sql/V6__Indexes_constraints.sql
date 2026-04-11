-- Additional covering indexes for reporting / statement generation
CREATE INDEX idx_transactions_created_id ON transactions (created_at, id);
CREATE INDEX idx_ledger_tx_account ON ledger_entries (transaction_id, account_id);
