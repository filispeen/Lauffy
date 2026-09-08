FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y \
    tar \
    xz-utils \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -fsSL https://github.com/luvit/lit/raw/master/get-lit.sh | sh

COPY package.lua ./

# Made for low end servers to install packages synchronously to avoid build freezing due to high CPU usage. (On my server)
RUN ./luvit -e "local deps = dofile('package.lua').dependencies; for _, pkg in pairs(deps) do os.execute('./lit install ' .. pkg) end"
RUN ./luvit ./deps/discord.lua/install.lua

FROM gcr.io/distroless/cc-debian12

COPY --from=builder /app/luvit /app/luvi /app/lit /usr/local/bin/
COPY --from=builder /app/deps /app/deps

WORKDIR /app
COPY . .

CMD ["/usr/local/bin/luvit", "main.lua"]