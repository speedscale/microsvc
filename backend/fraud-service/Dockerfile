FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum* ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /fraud-service ./cmd/server

# ---- runtime ----
FROM alpine:3.20

RUN addgroup -g 10001 -S fraud && adduser -u 10001 -S fraud -G fraud

COPY --from=builder /fraud-service /usr/local/bin/fraud-service

USER fraud

EXPOSE 50051

ENTRYPOINT ["fraud-service"]
