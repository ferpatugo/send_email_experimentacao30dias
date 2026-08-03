# ==========================================================================
# Dockerfile
# Usa rocker/r2u: instala pacotes R como binarios pre-compilados via apt
# (Posit Package Manager), em vez de compilar do zero. Muito mais rapido
# (~1-2 min em vez de ~15 min) e resolve sozinho dependencias de sistema
# (libsodium, libpq, etc.) automaticamente via apt.
#
# Usado pelos DOIS servicos do Railway (webhook e cron), a partir do mesmo
# repositorio. O que muda entre eles e o "Start Command" configurado nas
# settings de cada servico no Railway (nao aqui no Dockerfile):
#
#   Servico "webhook" (Settings > Deploy > Custom Start Command):
#     R -e "plumber::pr('webhook_api.R') |> plumber::pr_run(host='0.0.0.0', port=as.integer(Sys.getenv('PORT')))"
#
#   Servico "cron" (mesmo repo, com Cron Schedule configurado nas settings):
#     Rscript send_followup_emails.R
# ==========================================================================
FROM rocker/r2u:jammy

WORKDIR /app

# Instala os pacotes R via apt/bspm (binarios, resolve dependencias de
# sistema sozinho - nao precisa listar libpq-dev/libsodium-dev manualmente)
COPY install_packages.R .
RUN Rscript install_packages.R

COPY . .

EXPOSE 8000

CMD ["R", "-e", "plumber::pr('webhook_api.R') |> plumber::pr_run(host='0.0.0.0', port=as.integer(Sys.getenv('PORT', 8000)))"]
