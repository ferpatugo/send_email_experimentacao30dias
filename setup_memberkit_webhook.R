# ==========================================================================
# setup_memberkit_webhook.R
# Roda UMA VEZ para cadastrar o webhook na sua conta Memberkit, apontando
# para o endpoint que vai rodar em webhook_api.R.
#
# Documentação: https://ajuda.memberkit.com.br/referencia-api/post-hooks
# ==========================================================================

library(httr2)

MEMBERKIT_API_KEY <- Sys.getenv("MEMBERKIT_API_KEY") # pegue em Configuracoes > API
WEBHOOK_URL        <- Sys.getenv("TRIAL_WEBHOOK_URL")  # ex: https://seu-dominio.com/webhook/trial-signup?token=SEU_TOKEN

stopifnot(nzchar(MEMBERKIT_API_KEY), nzchar(WEBHOOK_URL))

resp <- request("https://memberkit.com.br/api/v1/hooks") |>
  req_url_query(api_key = MEMBERKIT_API_KEY) |>
  req_method("POST") |>
  req_headers("Content-Type" = "application/json") |>
  req_body_json(list(
    url    = WEBHOOK_URL,
    status = "active",
    events = list("membership_created") # nome do evento no cadastro (com underscore);
                                         # o payload entregue vem com type="membership.created" (com ponto)
  )) |>
  req_perform()

cat("Webhook cadastrado:\n")
print(resp_body_json(resp))

# Guarde o "id" retornado - serve para atualizar (PUT) ou remover (DELETE)
# o webhook depois em /api/v1/hooks/{id}, se precisar.
