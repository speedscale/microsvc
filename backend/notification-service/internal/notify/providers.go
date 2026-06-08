package notify

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

type TransactionInfo struct {
	TransactionID string
	UserID        string
	Amount        float64
	Type          string
	Status        string
}

type Notifier struct {
	client          *http.Client
	sendgridKey     string
	twilioSID       string
	twilioToken     string
	slackWebhookURL string
}

func NewNotifier() *Notifier {
	return &Notifier{
		client:          &http.Client{Timeout: 5 * time.Second},
		sendgridKey:     envOr("SENDGRID_API_KEY", "SG.mock-key-for-speedscale-demo"),
		twilioSID:       envOr("TWILIO_ACCOUNT_SID", "AC-mock-sid-for-speedscale-demo"),
		twilioToken:     envOr("TWILIO_AUTH_TOKEN", "mock-token-for-speedscale-demo"),
		slackWebhookURL: envOr("SLACK_WEBHOOK_URL", "https://slack-webhook.example.com/mock-webhook"),
	}
}

func (n *Notifier) FanOut(ctx context.Context, txn TransactionInfo) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var wg sync.WaitGroup
	wg.Add(3)

	go func() {
		defer wg.Done()
		if err := n.sendEmail(ctx, txn); err != nil {
			log.Printf("sendgrid error: %v", err)
		} else {
			log.Printf("sendgrid call completed for txn=%s", txn.TransactionID)
		}
	}()

	go func() {
		defer wg.Done()
		if err := n.sendSMS(ctx, txn); err != nil {
			log.Printf("twilio error: %v", err)
		} else {
			log.Printf("twilio call completed for txn=%s", txn.TransactionID)
		}
	}()

	go func() {
		defer wg.Done()
		if err := n.sendSlack(ctx, txn); err != nil {
			log.Printf("slack error: %v", err)
		} else {
			log.Printf("slack call completed for txn=%s", txn.TransactionID)
		}
	}()

	wg.Wait()
}

func (n *Notifier) sendEmail(ctx context.Context, txn TransactionInfo) error {
	body := map[string]interface{}{
		"personalizations": []map[string]interface{}{
			{"to": []map[string]string{{"email": "customer@example.com"}}},
		},
		"from":    map[string]string{"email": "alerts@apexbanking.com"},
		"subject": fmt.Sprintf("Transaction %s: %s", txn.Status, txn.TransactionID),
		"content": []map[string]string{
			{
				"type":  "text/plain",
				"value": fmt.Sprintf("Transaction %s of $%.2f (%s) is %s.", txn.TransactionID, txn.Amount, txn.Type, txn.Status),
			},
		},
	}
	payload, _ := json.Marshal(body)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, "https://api.sendgrid.com/v3/mail/send", bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+n.sendgridKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := n.client.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}

func (n *Notifier) sendSMS(ctx context.Context, txn TransactionInfo) error {
	endpoint := fmt.Sprintf("https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json", n.twilioSID)

	form := url.Values{}
	form.Set("To", "+15551234567")
	form.Set("From", "+15559876543")
	form.Set("Body", fmt.Sprintf("Apex Banking: your %s of $%.2f is %s (ref: %s)", txn.Type, txn.Amount, txn.Status, txn.TransactionID))

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.SetBasicAuth(n.twilioSID, n.twilioToken)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := n.client.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}

func (n *Notifier) sendSlack(ctx context.Context, txn TransactionInfo) error {
	body := map[string]string{
		"text":     fmt.Sprintf("[%s] Transaction %s: $%.2f %s", txn.Status, txn.TransactionID, txn.Amount, txn.Type),
		"channel":  "#transaction-alerts",
		"username": "apex-banking-bot",
	}
	payload, _ := json.Marshal(body)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, n.slackWebhookURL, bytes.NewReader(payload))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := n.client.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
