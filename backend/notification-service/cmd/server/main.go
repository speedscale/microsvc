package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"

	"github.com/speedscale/microsvc/notification-service/internal/api"
	"github.com/speedscale/microsvc/notification-service/internal/consumer"
)

func main() {
	port := envOrDefault("HTTP_PORT", "8080")
	brokers := strings.Split(envOrDefault("KAFKA_BROKERS", "banking-kafka:9092"), ",")
	topic := envOrDefault("KAFKA_TOPIC", "transaction-events")

	c := consumer.New(brokers, topic, "notification-service")
	defer c.Close()

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()

	go c.Run(ctx)

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: api.NewHandler(c.Buffer),
	}

	go func() {
		<-ctx.Done()
		log.Println("shutting down HTTP server")
		srv.Shutdown(context.Background())
	}()

	log.Printf("HTTP server listening on :%s", port)
	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("HTTP server error: %v", err)
	}
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
