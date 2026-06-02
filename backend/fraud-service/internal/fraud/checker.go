package fraud

import (
	"context"
	"time"

	fraudv1 "github.com/speedscale/microsvc/fraud-service/gen/fraud/v1"
	"github.com/speedscale/microsvc/fraud-service/internal/metrics"
)

// Checker implements fraudv1.FraudCheckerServer.
type Checker struct {
	fraudv1.UnimplementedFraudCheckerServer
}

// CheckTransaction applies rule-based fraud detection and records metrics.
func (c *Checker) CheckTransaction(_ context.Context, req *fraudv1.TransactionRequest) (*fraudv1.FraudCheckResponse, error) {
	start := time.Now()
	resp := evaluate(req)
	metrics.Observe(resp.GetApproved(), resp.GetReason(), time.Since(start), float64(resp.GetRiskScore()))
	return resp, nil
}

// evaluate runs the rule-based scoring with a small artificial delay to
// simulate real fraud-check latency.
func evaluate(req *fraudv1.TransactionRequest) *fraudv1.FraudCheckResponse {
	time.Sleep(7 * time.Millisecond)

	amount := req.GetAmount()

	switch {
	case amount > 1000:
		return &fraudv1.FraudCheckResponse{
			Approved:  false,
			RiskScore: 0.9,
			Reason:    "Amount exceeds limit",
		}

	case req.GetTransactionType() == "WITHDRAWAL" && amount > 500:
		return &fraudv1.FraudCheckResponse{
			Approved:  false,
			RiskScore: 0.7,
			Reason:    "High withdrawal amount",
		}

	default:
		score := amount / 2000
		if score > 0.5 {
			score = 0.5
		}
		return &fraudv1.FraudCheckResponse{
			Approved:  true,
			RiskScore: score,
			Reason:    "OK",
		}
	}
}
