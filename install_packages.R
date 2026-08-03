pkgs <- c(
  "plumber", "DBI", "RPostgres", "jsonlite",
  "blastula", "glue", "httr2" 
)
install.packages(pkgs, repos = "https://cloud.r-project.org")

# Falha o build explicitamente se algum pacote nao tiver instalado,
# em vez de deixar a imagem subir "quebrada" silenciosamente.
faltando <- setdiff(pkgs, rownames(installed.packages()))
if (length(faltando) > 0) {
  stop("Falha ao instalar pacote(s): ", paste(faltando, collapse = ", "))
}
cat("Todos os pacotes instalados com sucesso:", paste(pkgs, collapse = ", "), "\n")
