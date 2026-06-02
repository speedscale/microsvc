package main

import (
	"log"
	"net"
	"os"

	"google.golang.org/grpc"

	"github.com/speedscale/microsvc/fraud-service/internal/fraud"

	fraudv1 "github.com/speedscale/microsvc/fraud-service/gen/fraud/v1"
)

func main() {
	port := os.Getenv("GRPC_PORT")
	if port == "" {
		port = "50051"
	}

	lis, err := net.Listen("tcp", ":"+port)
	if err != nil {
		log.Fatalf("failed to listen on :%s: %v", port, err)
	}

	srv := grpc.NewServer()
	fraudv1.RegisterFraudCheckerServer(srv, &fraud.Checker{})

	log.Printf("fraud-service listening on :%s", port)
	if err := srv.Serve(lis); err != nil {
		log.Fatalf("server exited: %v", err)
	}
}
