# ==========================================================================
# db_utils.R
# Conexao compartilhada com Postgres, usada tanto pelo webhook_api.R
# (servico web) quanto pelo send_followup_emails.R (servico cron).
# No Railway, ao adicionar o addon Postgres e "linkar" aos dois servicos,
# a variavel DATABASE_URL e injetada automaticamente em ambos.
# ==========================================================================

library(DBI)
library(RPostgres)

connect_db <- function() {
  db_url <- Sys.getenv("DATABASE_URL")
  if (!nzchar(db_url)) {
    stop("DATABASE_URL nao definida. No Railway, linke o addon Postgres a este servico.")
  }

  # DATABASE_URL vem no formato: postgres://user:pass@host:port/dbname
  parsed <- httr2::url_parse(db_url)

  dbConnect(
    RPostgres::Postgres(),
    dbname   = sub("^/", "", parsed$path),
    host     = parsed$hostname,
    port     = as.integer(parsed$port %||% 5432),
    user     = parsed$username,
    password = parsed$password,
    sslmode  = "require"
  )
}

`%||%` <- function(a, b) if (is.null(a) || is.na(a) || !nzchar(as.character(a))) b else a

init_db <- function(con) {
  dbExecute(con, "
    CREATE TABLE IF NOT EXISTS trial_signups (
      id              SERIAL PRIMARY KEY,
      membership_id   TEXT UNIQUE,
      user_id         TEXT,
      name            TEXT,
      email           TEXT NOT NULL,
      signup_date     TIMESTAMPTZ NOT NULL,
      send_date       TIMESTAMPTZ NOT NULL,
      email_sent      INTEGER DEFAULT 0,
      sent_at         TIMESTAMPTZ,
      raw_payload     TEXT
    )
  ")
}
