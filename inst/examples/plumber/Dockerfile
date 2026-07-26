# Plumber API for a governed agent built on
# securer + secureguard + securetools.
#
# Build (from this directory):
#   docker build -t securetools-plumber .
# Run:
#   docker run --rm -p 8000:8000 securetools-plumber

FROM rocker/r-ver:4.5.1

RUN Rscript -e "install.packages(c('pak', 'plumber'), repos = 'https://cloud.r-project.org')" \
 && Rscript -e "pak::pak(c('ian-flores/securer', 'ian-flores/secureguard', 'ian-flores/securetools'))"

# Run as a non-root user
RUN useradd --create-home ruser
USER ruser
WORKDIR /app

COPY plumber.R /app/plumber.R
COPY entrypoint.R /app/entrypoint.R

EXPOSE 8000

CMD ["Rscript", "entrypoint.R"]
