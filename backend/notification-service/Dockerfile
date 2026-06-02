FROM golang:1.23-alpine AS builder

WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -o /notification-service ./cmd/server

FROM alpine:3.19

RUN addgroup -S app && adduser -S -G app app

COPY --from=builder /notification-service /notification-service

USER app
EXPOSE 8080

ENTRYPOINT ["/notification-service"]
