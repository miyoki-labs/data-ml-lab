FROM python:3.13-slim

# compose の secrets は元ファイルの権限（600・所有者 uid 1000）のまま見えるので、同じ uid で動かす
ARG UID=1000
RUN useradd --uid "${UID}" --create-home app

WORKDIR /app
COPY collector/ collector/
COPY tests/ tests/
COPY scripts/ scripts/
RUN chmod 755 scripts/*.sh

USER app
CMD ["python", "-m", "collector.fetch_one", "--help"]
