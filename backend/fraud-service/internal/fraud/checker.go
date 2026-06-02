package fraud

import (
	"context"
	"time"

	fraudv1 "github.com/speedscale/microsvc/fraud-service/gen/fraud/v1"
)

// Checker implements fraudv1.FraudCheckerServer.
type Checker struct {
	fraudv1.UnimplementedFraudCheckerServer
}

// CheckTransaction applies rule-based fraud detection with a small artificial delay.
func (c *Checker) CheckTransaction(_ context.Context, req *fraudv1.TransactionRequest) (*fraudv1.FraudCheckResponse, error) {
	// Simulate real fraud-check latency.
	time.Sleep(7 * time.Millisecond)

	amount := req.GetAmount()

	switch {
	case amount > 1000:
		return &fraudv1.FraudCheckResponse{
			Approved:  false,
			RiskScore: 0.9,
			Reason:    "Amount exceeds limit",
		}, nil

	case req.GetTransactionType() == "WITHDRAWAL" && amount > 500:
		return &fraudv1.FraudCheckResponse{
			Approved:  false,
			RiskScore: 0.7,
			Reason:    "High withdrawal amount",
		}, nil

	default:
		score := amount / 2000
		if score > 0.5 {
			score = 0.5
		}
		return &fraudv1.FraudCheckResponse{
			Approved:  true,
			RiskScore: score,
			Reason:    "OK",
		}, nil
	}
}
