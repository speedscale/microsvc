package main

import (
	"log"
	"net"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"google.golang.org/grpc"
	"google.golang.org/grpc/keepalive"

	"github.com/speedscale/microsvc/fraud-service/internal/fraud"

	fraudv1 "github.com/speedscale/microsvc/fraud-service/gen/fraud/v1"
)

func main() {
	port := envOrDefault("GRPC_PORT", "8080")
	metricsPort := envOrDefault("METRICS_PORT", "9091")

	go serveMetrics(metricsPort)

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("failed to listen on :%s: %v", port, err)
	}

	// ebpf observability: force connections to recycle after 1 minute so nettap can observe the connection
	// start and allow rrpairs to be correctly identified and parsed
	srv := grpc.NewServer(
		grpc.KeepaliveParams(keepalive.ServerParameters{
			MaxConnectionAge:      1 * time.Minute,
			MaxConnectionAgeGrace: 5 * time.Second,
		}),
	)
	fraudv1.RegisterFraudCheckerServer(srv, &fraud.Checker{})

	log.Printf("fraud-service listening on :%s", port)
	if err := srv.Serve(lis); err != nil {
		log.Fatalf("server exited: %v", err)
	}
}

// serveMetrics exposes Prometheus metrics on a dedicated HTTP port so the
// gRPC port stays protocol-pure.
func serveMetrics(port string) {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	log.Printf("fraud-service metrics on :%s/metrics", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Printf("metrics server stopped: %v", err)
	}
}

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
