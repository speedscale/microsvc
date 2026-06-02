package fraud

import (
	"context"
	"testing"

	fraudv1 "github.com/speedscale/microsvc/fraud-service/gen/fraud/v1"
	"github.com/speedscale/microsvc/fraud-service/internal/metrics"

	"github.com/prometheus/client_golang/prometheus/testutil"
)

func TestCheckTransaction(t *testing.T) {
	cases := []struct {
		name         string
		amount       float64
		txType       string
		wantApproved bool
		wantReason   string
	}{
		{"over limit", 1500, "DEPOSIT", false, "Amount exceeds limit"},
		{"high withdrawal", 600, "WITHDRAWAL", false, "High withdrawal amount"},
		{"normal", 100, "DEPOSIT", true, "OK"},
	}

	c := &Checker{}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			resp, err := c.CheckTransaction(context.Background(), &fraudv1.TransactionRequest{
				Amount:          tc.amount,
				TransactionType: tc.txType,
			})
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if resp.GetApproved() != tc.wantApproved {
				t.Errorf("approved = %v, want %v", resp.GetApproved(), tc.wantApproved)
			}
			if resp.GetReason() != tc.wantReason {
				t.Errorf("reason = %q, want %q", resp.GetReason(), tc.wantReason)
			}
		})
	}
}

func TestCheckTransactionRecordsMetrics(t *testing.T) {
	metrics.ChecksTotal.Reset()

	c := &Checker{}
	if _, err := c.CheckTransaction(context.Background(), &fraudv1.TransactionRequest{
		Amount:          50,
		TransactionType: "DEPOSIT",
	}); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if got := testutil.ToFloat64(metrics.ChecksTotal.WithLabelValues("true", "OK")); got != 1 {
		t.Errorf("fraud_checks_total{approved=true,reason=OK} = %v, want 1", got)
	}
}
