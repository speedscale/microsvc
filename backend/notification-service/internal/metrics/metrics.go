package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

var (
	// EventsConsumed counts transaction events consumed from Kafka.
	EventsConsumed = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "notification_events_consumed_total",
		Help: "Total transaction events consumed from Kafka, by type and status.",
	}, []string{"transaction_type", "status"})

	// ConsumeErrors counts read/decode failures while consuming Kafka messages.
	ConsumeErrors = promauto.NewCounter(prometheus.CounterOpts{
		Name: "notification_consume_errors_total",
		Help: "Total errors encountered while consuming or decoding Kafka messages.",
	})

	// BufferEvents reports how many events are currently held in the ring buffer.
	BufferEvents = promauto.NewGauge(prometheus.GaugeOpts{
		Name: "notification_buffer_events",
		Help: "Current number of events held in the in-memory ring buffer.",
	})
)
