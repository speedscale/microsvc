package consumer

import (
	"testing"

	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/speedscale/microsvc/notification-service/internal/metrics"
)

func TestRingBufferLatestAndForUser(t *testing.T) {
	var rb RingBuffer
	rb.Push(&TransactionEvent{TransactionID: "1", UserID: "alice"})
	rb.Push(&TransactionEvent{TransactionID: "2", UserID: "bob"})
	rb.Push(&TransactionEvent{TransactionID: "3", UserID: "alice"})

	latest := rb.Latest(2)
	if len(latest) != 2 || latest[0].TransactionID != "3" || latest[1].TransactionID != "2" {
		t.Fatalf("Latest(2) returned unexpected order: %+v", latest)
	}

	alice := rb.ForUser("alice", 10)
	if len(alice) != 2 || alice[0].TransactionID != "3" || alice[1].TransactionID != "1" {
		t.Fatalf("ForUser(alice) returned unexpected events: %+v", alice)
	}
}

func TestRingBufferUpdatesBufferGauge(t *testing.T) {
	metrics.BufferEvents.Set(0)

	var rb RingBuffer
	rb.Push(&TransactionEvent{TransactionID: "1", UserID: "alice"})
	rb.Push(&TransactionEvent{TransactionID: "2", UserID: "bob"})

	if got := testutil.ToFloat64(metrics.BufferEvents); got != 2 {
		t.Errorf("notification_buffer_events = %v, want 2", got)
	}
}
