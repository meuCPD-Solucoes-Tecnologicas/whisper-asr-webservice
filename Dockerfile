# Etapa para construir o FFmpeg
FROM debian:bookworm-slim AS ffmpeg

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get -qq update \
    && apt-get -qq install --no-install-recommends \
    build-essential \
    git \
    pkg-config \
    yasm \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/FFmpeg/FFmpeg.git --depth 1 --branch n6.1.1 --single-branch /FFmpeg-6.1.1

WORKDIR /FFmpeg-6.1.1

RUN PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
      --prefix="$HOME/ffmpeg_build" \
      --pkg-config-flags="--static" \
      --extra-cflags="-I$HOME/ffmpeg_build/include" \
      --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
      --extra-libs="-lpthread -lm" \
      --ld="g++" \
      --bindir="$HOME/bin" \
      --disable-doc \
      --disable-htmlpages \
      --disable-podpages \
      --disable-txtpages \
      --disable-network \
      --disable-autodetect \
      --disable-hwaccels \
      --disable-ffprobe \
      --disable-ffplay \
      --enable-filter=copy \
      --enable-protocol=file \
      --enable-small && \
    PATH="$HOME/bin:$PATH" make -j$(nproc) && \
    make install && \
    hash -r

# Etapa para copiar o Swagger UI
FROM swaggerapi/swagger-ui:v5.9.1 AS swagger-ui

# Etapa principal da aplicação
FROM python:3.10-bookworm

# Variável de ambiente para o ambiente virtual do Poetry
ENV POETRY_VENV=/app/.venv

# Instala o Poetry e cria o ambiente virtual
RUN python3 -m venv $POETRY_VENV \
    && $POETRY_VENV/bin/pip install -U pip setuptools \
    && $POETRY_VENV/bin/pip install poetry==1.6.1

ENV PATH="${PATH}:${POETRY_VENV}/bin"

WORKDIR /app

# Copia os arquivos da aplicação e dependências
COPY . /app
COPY --from=ffmpeg /FFmpeg-6.1.1 /FFmpeg-6.1.1
COPY --from=ffmpeg /root/bin/ffmpeg /usr/local/bin/ffmpeg
COPY --from=swagger-ui /usr/share/nginx/html/swagger-ui.css swagger-ui-assets/swagger-ui.css
COPY --from=swagger-ui /usr/share/nginx/html/swagger-ui-bundle.js swagger-ui-assets/swagger-ui-bundle.js

# Configura o Poetry e instala as dependências
RUN poetry config virtualenvs.in-project true
RUN poetry install

# Defina o IP SSL padrão
ARG SSL_IP=127.0.0.1
ENV SSL_IP=${SSL_IP}

# Instale o OpenSSL para geração dos certificados
RUN apt-get update && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*

# Adicione um script de inicialização para gerar o certificado
COPY generate_cert.sh /app/generate_cert.sh
RUN chmod +x /app/generate_cert.sh

# Exponha a porta do serviço HTTPS
EXPOSE 9000

# Defina o ENTRYPOINT para gerar os certificados e iniciar o Uvicorn com SSL
ENTRYPOINT ["/bin/bash", "-c", "/app/generate_cert.sh && uvicorn app.webservice:app --host 0.0.0.0 --port 9000 --ssl-keyfile /app/server.key --ssl-certfile /app/server.crt"]
