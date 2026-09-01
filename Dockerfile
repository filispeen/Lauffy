FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG LUVI_VERSION=2.14.0
ARG LIT_VERSION=3.8.5

RUN curl -fsSL https://github.com/luvit/lit/raw/master/get-lit.sh | sh

COPY package.lua ./
RUN ./lit install

FROM gcr.io/distroless/cc-debian12

COPY --from=builder /app/luvit /app/luvi /app/lit /usr/local/bin/
COPY --from=builder /app/deps /app/deps

WORKDIR /app
COPY . .

CMD ["/usr/local/bin/luvit", "main.lua"]
