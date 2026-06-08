package fraud

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

	fraudv1 "github.com/speedscale/microsvc/fraud-service/gen/fraud/v1"
)

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

var externalClient = &http.Client{Timeout: 5 * time.Second}

func fanOutExternalChecks(ctx context.Context, req *fraudv1.TransactionRequest) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	var wg sync.WaitGroup
	wg.Add(3)

	go func() {
		defer wg.Done()
		callStripeRadar(ctx, req)
	}()

	go func() {
		defer wg.Done()
		callSiftScience(ctx, req)
	}()

	go func() {
		defer wg.Done()
		callMaxMind(ctx, req)
	}()

	wg.Wait()
}

func callStripeRadar(ctx context.Context, req *fraudv1.TransactionRequest) {
	apiKey := envOrDefault("STRIPE_API_KEY", "sk_test_fake_key_for_demo")

	form := url.Values{}
	form.Set("value_list", "rsl_fraud_demo")
	form.Set("value", req.GetUserId())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.stripe.com/v1/radar/value_list_items",
		strings.NewReader(form.Encode()))
	if err != nil {
		log.Printf("stripe: build request: %v", err)
		return
	}
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)
	httpReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := externalClient.Do(httpReq)
	if err != nil {
		log.Printf("stripe: %v", err)
		return
	}
	resp.Body.Close()
	log.Printf("stripe: status %d", resp.StatusCode)
}

func callSiftScience(ctx context.Context, req *fraudv1.TransactionRequest) {
	apiKey := envOrDefault("SIFT_API_KEY", "fake_sift_key_for_demo")

	body := map[string]interface{}{
		"$api_key":  apiKey,
		"$type":     "$transaction",
		"$amount":   int64(req.GetAmount() * 1e6),
		"$user_id":  req.GetUserId(),
		"$currency_code": "USD",
		"$transaction_id": fmt.Sprintf("%s-%d", req.GetAccountId(), time.Now().UnixMilli()),
	}

	payload, err := json.Marshal(body)
	if err != nil {
		log.Printf("sift: marshal: %v", err)
		return
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.sift.com/v205/events",
		bytes.NewReader(payload))
	if err != nil {
		log.Printf("sift: build request: %v", err)
		return
	}
	httpReq.Header.Set("Content-Type", "application/json")

	resp, err := externalClient.Do(httpReq)
	if err != nil {
		log.Printf("sift: %v", err)
		return
	}
	resp.Body.Close()
	log.Printf("sift: status %d", resp.StatusCode)
}

func callMaxMind(ctx context.Context, req *fraudv1.TransactionRequest) {
	accountID := envOrDefault("MAXMIND_ACCOUNT_ID", "000000")
	licenseKey := envOrDefault("MAXMIND_LICENSE_KEY", "fake_maxmind_key_for_demo")

	body := map[string]interface{}{
		"device": map[string]string{
			"ip_address": "198.51.100.1",
		},
		"event": map[string]string{
			"transaction_id": fmt.Sprintf("%s-%d", req.GetAccountId(), time.Now().UnixMilli()),
		},
	}

	payload, err := json.Marshal(body)
	if err != nil {
		log.Printf("maxmind: marshal: %v", err)
		return
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://minfraud.maxmind.com/minfraud/v2.0/score",
		bytes.NewReader(payload))
	if err != nil {
		log.Printf("maxmind: build request: %v", err)
		return
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.SetBasicAuth(accountID, licenseKey)

	resp, err := externalClient.Do(httpReq)
	if err != nil {
		log.Printf("maxmind: %v", err)
		return
	}
	resp.Body.Close()
	log.Printf("maxmind: status %d", resp.StatusCode)
}
