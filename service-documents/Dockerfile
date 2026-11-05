# Service de documents Akonta (FastAPI) : PDF, Excel, liasse DGI.
# Construction : docker build -t akonta-documents service-documents
FROM python:3.13-slim

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /srv

# Dépendances d'abord (couche mise en cache tant que le verrou ne change pas)
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

COPY app ./app

# Utilisateur sans privilèges
RUN useradd --system --no-create-home akonta && chown -R akonta /srv
USER akonta

# Le modèle Excel DGI n'est pas versionné : le monter sur ce chemin (volume Dokploy)
ENV AKONTA_DGI_TEMPLATE=/data/modele-dgi.xlsm \
    PATH="/srv/.venv/bin:$PATH"

EXPOSE 8100
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8100/health').status==200 else 1)"

# AKONTA_SERVICE_KEY est obligatoire et fournie à l'exécution, jamais dans l'image
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8100"]
