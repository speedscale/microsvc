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
	"github.com/speedscale/microsvc/notification-service/internal/store"
)

func main() {
	port := envOrDefault("HTTP_PORT", "8080")
	brokers := strings.Split(envOrDefault("KAFKA_BROKERS", "banking-kafka:9092"), ",")
	topic := envOrDefault("KAFKA_TOPIC", "transaction-events")
	mongoURI := envOrDefault("MONGO_URI", "mongodb://banking-mongodb:27017")

	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGTERM, syscall.SIGINT)
	defer cancel()

	var mongoStore consumer.Store
	ms, err := store.NewMongoStore(ctx, mongoURI, "notifications", "events")
	if err != nil {
		log.Printf("WARNING: MongoDB unavailable (%v), falling back to in-memory only", err)
	} else {
		mongoStore = ms
	}

	c := consumer.New(brokers, topic, "notification-service", mongoStore)
	defer c.Close()

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
