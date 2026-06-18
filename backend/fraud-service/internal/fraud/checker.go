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

// highRiskMCCs are merchant category codes (ISO 18245) that warrant
// external provider verification (Sift / Stripe Radar / MaxMind) on top of
// rule-based scoring. Low-risk categories are scored on the rule engine
// alone to keep p99 latency down and reduce per-txn provider cost.
var highRiskMCCs = map[string]string{
	"5812": "restaurants",
	"5912": "drug-stores",
	"5732": "consumer-electronics",
	"7995": "gambling",
	"5410": "grocery-stores",
}

// CheckTransaction applies rule-based fraud detection and records metrics.
func (c *Checker) CheckTransaction(ctx context.Context, req *fraudv1.TransactionRequest) (*fraudv1.FraudCheckResponse, error) {
	start := time.Now()
	resp := evaluate(req)

	// Escalate only high-risk merchant categories to external providers.
	_, escalate := highRiskMCCs[req.GetMerchantCategory()]
	var results []ExternalResult
	if escalate {
		results = fanOutExternalChecks(ctx, req)
	}

	allFailed := len(results) > 0
	for _, r := range results {
		if r.OK() {
			allFailed = false
			break
		}
	}

	// Medium-risk transactions that pass rule-based scoring still need
	// external provider verification. Reject them when all providers are down.
	if allFailed && resp.GetApproved() && resp.GetRiskScore() > 0.3 {
		resp = &fraudv1.FraudCheckResponse{
			Approved:  false,
			RiskScore: resp.GetRiskScore() + 0.3,
			Reason:    "external-verification-unavailable",
		}
	}

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
