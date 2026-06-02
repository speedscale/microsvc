package consumer

import (
	"context"
	"encoding/json"
	"log"
	"sync"
	"time"

	kafka "github.com/segmentio/kafka-go"
)

const ringSize = 1000

// TransactionEvent mirrors the upstream transaction-events message schema.
type TransactionEvent struct {
	TransactionID   string    `json:"transaction_id"`
	AccountID       string    `json:"account_id"`
	UserID          string    `json:"user_id"`
	Amount          float64   `json:"amount"`
	TransactionType string    `json:"transaction_type"`
	Status          string    `json:"status"`
	Timestamp       time.Time `json:"timestamp"`
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
		if e != nil && e.UserID == userID {
			out = append(out, e)
			if len(out) >= n {
				break
			}
		}
	}
	return out
}

// Consumer reads from Kafka and populates the ring buffer.
type Consumer struct {
	reader *kafka.Reader
	Buffer *RingBuffer
}

func New(brokers []string, topic, groupID string) *Consumer {
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
			log.Printf("kafka read error: %v", err)
			continue
		}
		var evt TransactionEvent
		if err := json.Unmarshal(m.Value, &evt); err != nil {
			log.Printf("unmarshal error (offset=%d): %v", m.Offset, err)
			continue
		}
		log.Printf("event: id=%s account=%s user=%s type=%s status=%s amount=%.2f",
			evt.TransactionID, evt.AccountID, evt.UserID,
			evt.TransactionType, evt.Status, evt.Amount)
		c.Buffer.Push(&evt)
	}
}

// Close shuts the Kafka reader.
func (c *Consumer) Close() error {
	return c.reader.Close()
}
