# ==========================================================================
# Dockerfile
# Usado pelos DOIS servicos do Railway (webhook e cron), a partir do mesmo
# repositorio. O que muda entre eles e o "Start Command" configurado nas
# settings de cada servico no Railway (nao aqui no Dockerfile):
#
#   Servico "webhook" (Deploy > Settings > Deploy > Custom Start Command):
#     R -e "plumber::pr('webhook_api.R') |> plumber::pr_run(host='0.0.0.0', port=as.integer(Sys.getenv('PORT')))"
#
#   Servico "cron" (mesmo repo, com Cron Schedule configurado nas settings):
#     Rscript send_followup_emails.R
# ==========================================================================
FROM rocker/r-ver:4.4.1

# Dependencias de sistema: libpq para RPostgres, libssl/libcurl para
# httr2/blastula, etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instala os pacotes R (cache de camada Docker: só reinstala se mudar)
COPY install_packages.R .
RUN Rscript install_packages.R

COPY . .

# Porta default para o servico web local (Railway sobrescreve via $PORT)
EXPOSE 8000

# Comando default (o servico "webhook" no Railway usa este; o "cron"
# sobrescreve com um Custom Start Command, ver topo do arquivo)
CMD ["R", "-e", "plumber::pr('webhook_api.R') |> plumber::pr_run(host='0.0.0.0', port=as.integer(Sys.getenv('PORT', 8000)))"]
