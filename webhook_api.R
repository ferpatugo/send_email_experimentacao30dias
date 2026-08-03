# ==========================================================================
# webhook_api.R
# API Plumber que recebe o webhook NATIVO do Memberkit (evento
# "membership.created") e filtra apenas a "Experimentacao CECD 3.0"
# (membership_level.id = 35542) para agendar o e-mail de follow-up de 7 dias.
#
# Formato REAL confirmado do payload:
# {
#   "data": {
#     "created_at": "2026-07-29T15:13:12.210-03:00",
#     "id": 13637640,
#     "membership_level": { "id": 35542, "name": "Experimentacao CECD 3.0" },
#     "user": { "id": 44881083, "email": "...", "full_name": "..." }
#   },
#   "type": "membership.created"
# }
#
# No Railway, este arquivo roda como o "start command" do servico web:
#   R -e "plumber::pr('webhook_api.R') |> plumber::pr_run(host='0.0.0.0', port=as.integer(Sys.getenv('PORT')))"
# (o Railway injeta a variavel PORT automaticamente)
# ==========================================================================

library(plumber)
library(jsonlite)
source("db_utils.R")

WEBHOOK_TOKEN  <- Sys.getenv("TRIAL_WEBHOOK_TOKEN", unset = "troque-este-token")
MEMBERSHIP_ID_EXPERIMENTACAO <- 35542L

# ---- Inicializa o banco (idempotente, roda ao subir o servico) -----------
{
  con <- connect_db()
  init_db(con)
  dbDisconnect(con)
}

#* @apiTitle CECD Trial Follow-up Webhook (Memberkit nativo)

#* Recebe o evento membership.created do Memberkit
#* @param req
#* @param res
#* @param token
#* @post /webhook/trial-signup
function(req, res, token = "") {

  if (!identical(token, WEBHOOK_TOKEN)) {
    res$status <- 401
    return(list(status = "error", message = "token invalido"))
  }

  body <- tryCatch(fromJSON(req$postBody, simplifyVector = TRUE),
                    error = function(e) NULL)
  if (is.null(body)) {
    res$status <- 400
    return(list(status = "error", message = "payload invalido"))
  }

  log_line <- function(status, membership_level_id = NA, email = NA, membership_id = NA) {
    cat(sprintf("[%s] status=%s membership_id=%s email=%s membership_level_id=%s\n",
                Sys.time(), status, membership_id, email, membership_level_id))
  }

  event_type <- body$type %||% NA_character_
  if (!identical(event_type, "membership.created")) {
    log_line(paste0("ignorado (type=", event_type, ")"))
    return(list(status = "ignorado", motivo = "type != membership.created"))
  }

  data_ev <- body$data
  membership_level_id <- as.integer(data_ev$membership_level$id %||% NA)
  membership_id        <- as.character(data_ev$id %||% NA)
  user_id               <- as.character(data_ev$user$id %||% NA)
  name                  <- as.character(data_ev$user$full_name %||% NA)
  email                 <- as.character(data_ev$user$email %||% NA)
  created_at_raw        <- as.character(data_ev$created_at %||% NA)

  if (is.na(membership_level_id) || membership_level_id != MEMBERSHIP_ID_EXPERIMENTACAO) {
    log_line("ignorado (nao e experimentacao)", membership_level_id, email, membership_id)
    return(list(status = "ignorado", motivo = "membership_level.id != 35542"))
  }

  if (is.na(email) || email == "") {
    res$status <- 422
    log_line("erro-sem-email", membership_level_id, email, membership_id)
    return(list(status = "error", message = "email ausente no payload"))
  }

  signup_date <- tryCatch(
    as.POSIXct(created_at_raw, format = "%Y-%m-%dT%H:%M:%OS%z", tz = "America/Sao_Paulo"),
    error = function(e) NA
  )
  if (is.na(signup_date)) signup_date <- Sys.time()
  send_date <- signup_date + as.difftime(7, units = "days")

  con <- connect_db()
  on.exit(dbDisconnect(con))

  resultado <- tryCatch({
    dbExecute(con, "
      INSERT INTO trial_signups (membership_id, user_id, name, email, signup_date, send_date, raw_payload)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      ON CONFLICT (membership_id) DO NOTHING
    ", params = list(
      membership_id, user_id, name, email, signup_date, send_date, req$postBody
    ))
    "ok"
  }, error = function(e) {
    cat("ERRO ao inserir:", conditionMessage(e), "\n")
    "erro"
  })

  log_line(paste("gravado:", resultado), membership_level_id, email, membership_id)
  list(status = "recebido", resultado = resultado, email = email,
       envio_programado_para = format(send_date, "%Y-%m-%d"))
}

#* Healthcheck
#* @get /health
function() {
  list(status = "ok", time = Sys.time())
}
