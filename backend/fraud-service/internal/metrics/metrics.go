package metrics

import (
	"strconv"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// ChecksTotal counts fraud checks by decision and reason.
	ChecksTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "fraud_checks_total",
		Help: "Total fraud checks processed, partitioned by decision and reason.",
	}, []string{"approved", "reason"})

	// CheckDuration measures end-to-end fraud evaluation latency.
	CheckDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "fraud_check_duration_seconds",
		Help:    "Latency of fraud check evaluations.",
		Buckets: prometheus.DefBuckets,
	})

	// RiskScore tracks the distribution of computed risk scores.
	RiskScore = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "fraud_risk_score",
		Help:    "Distribution of computed risk scores (0.0-1.0).",
		Buckets: []float64{0, 0.1, 0.25, 0.5, 0.7, 0.9, 1.0},
	})
)

// Observe records the outcome of a single fraud check.
func Observe(approved bool, reason string, dur time.Duration, risk float64) {
	ChecksTotal.WithLabelValues(strconv.FormatBool(approved), reason).Inc()
	CheckDuration.Observe(dur.Seconds())
	RiskScore.Observe(risk)
}
