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

	ExternalRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "fraud_external_requests_total",
		Help: "Outbound fraud-check API calls by provider and HTTP status.",
	}, []string{"provider", "status"})

	ExternalRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "fraud_external_request_duration_seconds",
		Help:    "Latency of outbound fraud-check API calls.",
		Buckets: prometheus.DefBuckets,
	}, []string{"provider"})
)

// Observe records the outcome of a single fraud check.
func Observe(approved bool, reason string, dur time.Duration, risk float64) {
	ChecksTotal.WithLabelValues(strconv.FormatBool(approved), reason).Inc()
	CheckDuration.Observe(dur.Seconds())
	RiskScore.Observe(risk)
}

// ObserveExternal records the outcome of an outbound API call.
func ObserveExternal(provider string, status int, dur time.Duration) {
	ExternalRequestsTotal.WithLabelValues(provider, strconv.Itoa(status)).Inc()
	ExternalRequestDuration.WithLabelValues(provider).Observe(dur.Seconds())
}
