FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN curl -fsSL https://github.com/luvit/lit/raw/master/get-lit.sh | sh

COPY package.lua ./

RUN attempt=1; \
    max_attempts=5; \
    until ./lit install; do \
      if [ "$attempt" -ge "$max_attempts" ]; then \
        echo "lit install failed after $max_attempts attempts" >&2; \
        exit 1; \
      fi; \
      delay=$((attempt * 5)); \
      echo "lit install failed; retrying in ${delay}s (attempt $((attempt + 1))/$max_attempts)" >&2; \
      sleep "$delay"; \
      attempt=$((attempt + 1)); \
    done

FROM gcr.io/distroless/cc-debian12

COPY --from=builder /app/luvit /app/luvi /app/lit /usr/local/bin/
COPY --from=builder /app/deps /app/deps

WORKDIR /app
COPY . .

CMD ["/usr/local/bin/luvit", "main.lua"]
