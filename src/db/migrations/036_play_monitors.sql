-- Layar Monitor Bermain dipasangkan ke terminal kasir seperti display pelanggan (src/services/playMonitors.js):
-- kode sekali pakai dari menu Monitor Bermain di kasir, lalu perangkatnya (TV/PC/tablet) memegang cookie sendiri.
-- Terpisah dari display pelanggan dan boleh lebih dari satu layar per kasir. Tanpa login; hanya kasir yang memasangkan.
ALTER TABLE pos_terminals
  ADD COLUMN monitor_code_hash       BYTEA,
  ADD COLUMN monitor_code_expires_at TIMESTAMPTZ;

CREATE TABLE play_monitors (
  id           BIGSERIAL    PRIMARY KEY,
  terminal_id  BIGINT       NOT NULL REFERENCES pos_terminals(id),
  token_hash   BYTEA        NOT NULL UNIQUE,
  paired_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
  seen_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX play_monitors_terminal_idx ON play_monitors (terminal_id);
