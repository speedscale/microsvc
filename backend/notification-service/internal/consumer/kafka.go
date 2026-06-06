package consumer

import (
	"context"
	"encoding/json"
	"log"
	"sync"
	"time"

	kafka "github.com/segmentio/kafka-go"

	"github.com/speedscale/microsvc/notification-service/internal/metrics"
)

const ringSize = 1000

// TransactionEvent mirrors the upstream transaction-events message schema.
// The Java producer sends transaction_id and user_id as JSON numbers and
// account_id as a number or null, so we use json.Number (nullable via pointer).
type TransactionEvent struct {
	TransactionID   json.Number  `json:"transaction_id"`
	AccountID       *json.Number `json:"account_id"`
	UserID          json.Number  `json:"user_id"`
	Amount          float64      `json:"amount"`
	TransactionType string       `json:"transaction_type"`
	Status          string       `json:"status"`
	Timestamp       time.Time    `json:"timestamp"`
}

// RingBuffer holds the last N events in insertion order.
type RingBuffer struct {
	mu     sync.Mutex
	events [ringSize]*TransactionEvent
	head   int // next write position
	count  int
}

func (r *RingBuffer) Push(e *TransactionEvent) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.events[r.head] = e
	r.head = (r.head + 1) % ringSize
	if r.count < ringSize {
		r.count++
	}
	metrics.BufferEvents.Set(float64(r.count))
}

// Latest returns up to n events, newest first.
func (r *RingBuffer) Latest(n int) []*TransactionEvent {
	r.mu.Lock()
	defer r.mu.Unlock()
	if n > r.count {
		n = r.count
	}
	out := make([]*TransactionEvent, 0, n)
	for i := 1; i <= n; i++ {
		idx := (r.head - i + ringSize) % ringSize
		out = append(out, r.events[idx])
	}
	return out
}

// ForUser returns up to n events for a specific userID, newest first.
func (r *RingBuffer) ForUser(userID string, n int) []*TransactionEvent {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]*TransactionEvent, 0)
	for i := 1; i <= r.count; i++ {
		idx := (r.head - i + ringSize) % ringSize
		e := r.events[idx]
		if e != nil && e.UserID.String() == userID {
			out = append(out, e)
			if len(out) >= n {
				break
			}
		}
	}
	return out
}

// Store persists events for durable retrieval.
type Store interface {
	Insert(ctx context.Context, evt *TransactionEvent) error
}

// Consumer reads from Kafka and populates both the ring buffer and a durable store.
type Consumer struct {
	reader *kafka.Reader
	Buffer *RingBuffer
	store  Store
}

func New(brokers []string, topic, groupID string, store Store) *Consumer {
	r := kafka.NewReader(kafka.ReaderConfig{
		Brokers:        brokers,
		Topic:          topic,
		GroupID:        groupID,
		MinBytes:       1,
		MaxBytes:       10e6,
		CommitInterval: time.Second,
	})
	return &Consumer{
		reader: r,
		Buffer: &RingBuffer{},
		store:  store,
	}
}

// Run blocks, consuming messages until ctx is cancelled.
func (c *Consumer) Run(ctx context.Context) {
	log.Printf("kafka consumer started (topic=%s)", c.reader.Config().Topic)
	for {
		m, err := c.reader.ReadMessage(ctx)
		if err != nil {
			if ctx.Err() != nil {
				log.Printf("kafka consumer stopped: %v", ctx.Err())
				return
			}
			metrics.ConsumeErrors.Inc()
			log.Printf("kafka read error: %v", err)
			continue
		}
		var evt TransactionEvent
		if err := json.Unmarshal(m.Value, &evt); err != nil {
			metrics.ConsumeErrors.Inc()
			log.Printf("unmarshal error (offset=%d): %v", m.Offset, err)
			continue
		}
		acctID := "null"
		if evt.AccountID != nil {
			acctID = evt.AccountID.String()
		}
		log.Printf("event: id=%s account=%s user=%s type=%s status=%s amount=%.2f",
			evt.TransactionID.String(), acctID, evt.UserID.String(),
			evt.TransactionType, evt.Status, evt.Amount)
		metrics.EventsConsumed.WithLabelValues(evt.TransactionType, evt.Status).Inc()
		c.Buffer.Push(&evt)
		if c.store != nil {
			if err := c.store.Insert(ctx, &evt); err != nil {
				log.Printf("mongo insert error: %v", err)
			}
		}
	}
}

// Close shuts the Kafka reader.
func (c *Consumer) Close() error {
	return c.reader.Close()
}
