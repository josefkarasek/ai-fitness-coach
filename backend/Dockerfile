FROM cgr.dev/chainguard/go:latest AS builder

WORKDIR /app

COPY go.mod go.sum* ./
RUN go mod download

COPY . .

RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/bin/api ./cmd/api

FROM cgr.dev/chainguard/static:latest

WORKDIR /app

COPY --from=builder /app/bin/api /app/api

ENTRYPOINT ["/app/api"]
