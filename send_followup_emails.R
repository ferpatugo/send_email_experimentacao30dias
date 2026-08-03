# ==========================================================================
# send_followup_emails.R
# Roda 1x por dia como um "Cron Job" service no Railway (agendado direto
# nas configuracoes do servico, sem precisar de cron do sistema operacional).
# Busca no Postgres quem completou 7 dias de experimentacao e ainda nao
# recebeu o e-mail, e envia via Gmail (SMTP com senha de app, via blastula).
# ==========================================================================

library(blastula)
library(glue)
source("db_utils.R")

# ---- Credenciais SMTP do Gmail -------------------------------------------
# As credenciais SMTP do blastula sao salvas como arquivo local
# (~/.blastula_keyring), o que NAO persiste em containers efemeros do
# Railway. Por isso, aqui usamos smtp_send() com usuario/senha vindos
# direto de variaveis de ambiente (mais simples de configurar no Railway).
GMAIL_USER     <- Sys.getenv("GMAIL_USER", unset = "profestathimarques@gmail.com")
GMAIL_APP_PASS <- Sys.getenv("GMAIL_APP_PASSWORD") # senha de app de 16 caracteres, sem espacos

if (!nzchar(GMAIL_APP_PASS)) {
  stop("GMAIL_APP_PASSWORD nao definida nas variaveis de ambiente do servico cron.")
}

creds <- creds_envvar(
  user        = GMAIL_USER,
  pass_envvar = "GMAIL_APP_PASSWORD",
  provider    = "gmail"
)

# ---- Busca quem esta pronto para receber o e-mail -------------------------
con <- connect_db()
on.exit(dbDisconnect(con))

pendentes <- dbGetQuery(con, "
  SELECT id, membership_id, name, email, signup_date, send_date
  FROM trial_signups
  WHERE email_sent = 0
    AND send_date <= NOW()
")

cat(sprintf("[%s] %d e-mail(s) pendente(s) de envio\n", Sys.time(), nrow(pendentes)))

if (nrow(pendentes) > 0) {
  for (i in seq_len(nrow(pendentes))) {
    row <- pendentes[i, ]
    primeiro_nome <- strsplit(trimws(row$name %||% "por aí"), " ")[[1]][1]

    email_obj <- compose_email(
      body = md(glue("
        Olá {primeiro_nome}!

        Já se passou uma semana desde que você começou sua **Experimentação
        gratuita de 30 dias** na CECD (Comunidade de Estatística e Ciência
        de Dados). 🎉

        Queremos saber: como está sendo sua experiência até aqui? Já deu
        uma olhada nas trilhas de conteúdo disponíveis?

        Se tiver qualquer dúvida ou quiser indicação de por onde começar,
        é só responder este e-mail.

        Um abraço,
        Prof. Thiago Marques
        CECD - Comunidade de Estatística e Ciência de Dados
      ")),
      footer = md("Você está recebendo este e-mail por estar na experimentação gratuita da CECD.")
    )

    resultado <- tryCatch({
      smtp_send(
        email_obj,
        from = GMAIL_USER,
        to = row$email,
        subject = "Como está sua primeira semana na CECD?",
        credentials = creds
      )
      TRUE
    }, error = function(e) {
      cat(sprintf("  ERRO ao enviar para %s: %s\n", row$email, conditionMessage(e)))
      FALSE
    })

    if (isTRUE(resultado)) {
      dbExecute(con, "
        UPDATE trial_signups
        SET email_sent = 1, sent_at = NOW()
        WHERE id = $1
      ", params = list(row$id))
      cat(sprintf("  OK: enviado para %s\n", row$email))
    }

    Sys.sleep(1) # evita rajada muito rapida no SMTP do Gmail
  }
}

cat(sprintf("[%s] Execucao concluida.\n", Sys.time()))
