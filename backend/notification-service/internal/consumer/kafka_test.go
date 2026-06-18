package consumer

import "testing"

func TestNewWithAuthPlainConfiguresDialer(t *testing.T) {
	c, err := NewWithAuth(
		[]string{"banking-kafka:9092"},
		"transaction-events",
		"notification-service",
		nil,
		AuthConfig{
			Mechanism: "PLAIN",
			Username:  "banking",
			Password:  "secret",
		},
	)
	if err != nil {
		t.Fatalf("NewWithAuth returned error: %v", err)
	}
	defer c.Close()

	if c.reader.Config().Dialer == nil {
		t.Fatal("expected SASL dialer")
	}
}

func TestNewWithAuthRequiresPlainCredentials(t *testing.T) {
	_, err := NewWithAuth(
		[]string{"banking-kafka:9092"},
		"transaction-events",
		"notification-service",
		nil,
		AuthConfig{Mechanism: "PLAIN"},
	)
	if err == nil {
		t.Fatal("expected missing credentials error")
	}
}

func TestNewWithAuthRejectsUnsupportedMechanism(t *testing.T) {
	_, err := NewWithAuth(
		[]string{"banking-kafka:9092"},
		"transaction-events",
		"notification-service",
		nil,
		AuthConfig{
			Mechanism: "SCRAM-SHA-256",
			Username:  "banking",
			Password:  "secret",
		},
	)
	if err == nil {
		t.Fatal("expected unsupported mechanism error")
	}
}
