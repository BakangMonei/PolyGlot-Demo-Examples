package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	_ "github.com/go-sql-driver/mysql"
)

func main() {
	useMem := os.Getenv("USE_MEMORY_STORE") == "true"
	var db *sql.DB
	if !useMem {
		dsn := os.Getenv("MYSQL_DSN")
		if dsn == "" {
			dsn = "root:financial_root@tcp(mysql:3306)/financial_platform?parseTime=true"
		}
		var err error
		db, err = sql.Open("mysql", dsn)
		if err != nil {
			log.Fatalf("mysql: %v", err)
		}
		db.SetMaxOpenConns(16)
		db.SetMaxIdleConns(8)
		db.SetConnMaxLifetime(5 * time.Minute)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok", "service": "account-go"})
	})

	mux.HandleFunc("/accounts/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		id := r.URL.Path[len("/accounts/"):]
		if id == "" {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		if db == nil {
			_ = json.NewEncoder(w).Encode(map[string]any{"id": id, "currency": "USD", "balance_minor": 0, "status": "active"})
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		var cur string
		var bal int64
		var st string
		err := db.QueryRowContext(ctx, `SELECT currency, balance_minor, status FROM accounts WHERE id = ?`, id).Scan(&cur, &bal, &st)
		if err == sql.ErrNoRows {
			http.Error(w, `{"error":"not_found"}`, http.StatusNotFound)
			return
		}
		if err != nil {
			log.Printf("query: %v", err)
			http.Error(w, `{"error":"internal"}`, http.StatusInternalServerError)
			return
		}
		_ = json.NewEncoder(w).Encode(map[string]any{"id": id, "currency": cur, "balance_minor": bal, "status": st})
	})

	mux.HandleFunc("/transactions", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		var body struct {
			AccountID             string  `json:"account_id"`
			AmountMinor           int64   `json:"amount_minor"`
			Type                  string  `json:"type"`
			CounterpartyAccountID *string `json:"counterparty_account_id"`
			Narrative             *string `json:"narrative"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, `{"error":"bad_json"}`, http.StatusBadRequest)
			return
		}
		idem := r.Header.Get("Idempotency-Key")
		if len(idem) < 8 {
			http.Error(w, `{"error":"idempotency"}`, http.StatusBadRequest)
			return
		}
		corr := r.Header.Get("X-Correlation-Id")
		w.Header().Set("Content-Type", "application/json")
		if db == nil {
			w.WriteHeader(http.StatusCreated)
			_ = json.NewEncoder(w).Encode(map[string]any{"id": "mem-tx", "account_id": body.AccountID, "amount_minor": body.AmountMinor, "type": body.Type, "status": "posted"})
			return
		}
		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()
		tx, err := db.BeginTx(ctx, nil)
		if err != nil {
			http.Error(w, `{"error":"tx"}`, http.StatusInternalServerError)
			return
		}

		txID := fmt.Sprintf("tx-%d", time.Now().UnixNano())
		res, err := tx.ExecContext(ctx, `INSERT IGNORE INTO transactions (id, account_id, amount_minor, type, status, counterparty_account_id, narrative, idempotency_key, correlation_id) VALUES (?,?,?,?,?,?,?,?,?)`,
			txID, body.AccountID, body.AmountMinor, body.Type, "posted", body.CounterpartyAccountID, body.Narrative, idem, nullString(corr))
		if err != nil {
			_ = tx.Rollback()
			log.Printf("insert tx: %v", err)
			http.Error(w, `{"error":"internal"}`, http.StatusInternalServerError)
			return
		}
		ra, _ := res.RowsAffected()
		if ra == 0 {
			var existing string
			if err := tx.QueryRowContext(ctx, `SELECT id FROM transactions WHERE idempotency_key = ?`, idem).Scan(&existing); err != nil {
				_ = tx.Rollback()
				http.Error(w, `{"error":"conflict"}`, http.StatusConflict)
				return
			}
			if err := tx.Commit(); err != nil {
				http.Error(w, `{"error":"commit"}`, http.StatusInternalServerError)
				return
			}
			w.WriteHeader(http.StatusOK)
			_ = json.NewEncoder(w).Encode(map[string]any{"id": existing, "status": "posted", "duplicate": true})
			return
		}

		var debit, credit int64
		if body.Type == "debit" {
			debit = body.AmountMinor
		} else {
			credit = body.AmountMinor
		}
		if _, err := tx.ExecContext(ctx, `INSERT INTO ledger_entries (transaction_id, account_id, debit_minor, credit_minor) VALUES (?,?,?,?)`, txID, body.AccountID, debit, credit); err != nil {
			_ = tx.Rollback()
			log.Printf("ledger: %v", err)
			http.Error(w, `{"error":"ledger"}`, http.StatusInternalServerError)
			return
		}
		delta := body.AmountMinor
		if body.Type == "debit" {
			delta = -body.AmountMinor
		}
		res2, err := tx.ExecContext(ctx, `UPDATE accounts SET balance_minor = balance_minor + ? WHERE id = ? AND balance_minor + ? >= 0`, delta, body.AccountID, delta)
		if err != nil {
			_ = tx.Rollback()
			http.Error(w, `{"error":"balance"}`, http.StatusInternalServerError)
			return
		}
		if n, _ := res2.RowsAffected(); n != 1 {
			_ = tx.Rollback()
			http.Error(w, `{"error":"insufficient_funds"}`, http.StatusConflict)
			return
		}
		if err := tx.Commit(); err != nil {
			http.Error(w, `{"error":"commit"}`, http.StatusInternalServerError)
			return
		}
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(map[string]any{"id": txID, "account_id": body.AccountID, "amount_minor": body.AmountMinor, "type": body.Type, "status": "posted"})
	})

	mux.HandleFunc("/reports/", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		aid := r.URL.Path[len("/reports/"):]
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{
			"account_id":     aid,
			"artifact_url":   nil,
			"generated_at":   time.Now().UTC().Format(time.RFC3339),
			"format":         r.URL.Query().Get("format"),
			"implementation": "account-go",
		})
	})

	addr := ":7101"
	if v := os.Getenv("PORT"); v != "" {
		addr = ":" + v
	}
	log.Printf("account-go listening %s (memory=%v)", addr, useMem)
	log.Fatal(http.ListenAndServe(addr, withCORS(mux)))
}

func nullString(s string) any {
	if s == "" {
		return nil
	}
	return s
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, Idempotency-Key, X-Correlation-Id")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}
