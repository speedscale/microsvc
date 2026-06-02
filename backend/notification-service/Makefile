.PHONY: build test tidy docker

build:
	go build -o bin/notification-service ./cmd/server

test:
	go test ./...

tidy:
	go mod tidy

docker:
	docker build -t notification-service:latest .
