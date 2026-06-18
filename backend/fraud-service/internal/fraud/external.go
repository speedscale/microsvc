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
	"github.com/speedscale/microsvc/fraud-service/internal/metrics"
)

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

var externalClient = &http.Client{Timeout: 5 * time.Second}

type ExternalResult struct {
	Provider string
	Status   int
	Err      error
}

func (r ExternalResult) OK() bool {
	return r.Err == nil && r.Status >= 200 && r.Status < 300
}

func fanOutExternalChecks(ctx context.Context, req *fraudv1.TransactionRequest) []ExternalResult {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()

	results := make([]ExternalResult, 3)
	var wg sync.WaitGroup
	wg.Add(3)

	go func() {
		defer wg.Done()
		results[0] = callStripeRadar(ctx, req)
	}()

	go func() {
		defer wg.Done()
		results[1] = callSiftScience(ctx, req)
	}()

	go func() {
		defer wg.Done()
		results[2] = callMaxMind(ctx, req)
	}()

	wg.Wait()
	return results
}

func callStripeRadar(ctx context.Context, req *fraudv1.TransactionRequest) ExternalResult {
	apiKey := envOrDefault("STRIPE_API_KEY", "sk_test_placeholder_key")

	form := url.Values{}
	form.Set("value_list", "rsl_fraud_demo")
	form.Set("value", req.GetUserId())

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.stripe.com/v1/radar/value_list_items",
		strings.NewReader(form.Encode()))
	if err != nil {
		log.Printf("stripe: build request: %v", err)
		return ExternalResult{Provider: "stripe", Err: err}
	}
	httpReq.Header.Set("Authorization", "Bearer "+apiKey)
	httpReq.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	start := time.Now()
	resp, err := externalClient.Do(httpReq)
	dur := time.Since(start)
	if err != nil {
		log.Printf("stripe: %v", err)
		metrics.ObserveExternal("stripe", 0, dur)
		return ExternalResult{Provider: "stripe", Err: err}
	}
	resp.Body.Close()
	log.Printf("stripe: status %d", resp.StatusCode)
	metrics.ObserveExternal("stripe", resp.StatusCode, dur)
	return ExternalResult{Provider: "stripe", Status: resp.StatusCode}
}

func callSiftScience(ctx context.Context, req *fraudv1.TransactionRequest) ExternalResult {
	apiKey := envOrDefault("SIFT_API_KEY", "placeholder_sift_key")

	body := map[string]interface{}{
		"$api_key":         apiKey,
		"$type":            "$transaction",
		"$amount":          int64(req.GetAmount() * 1e6),
		"$user_id":         req.GetUserId(),
		"$currency_code":   "USD",
		"$transaction_id":  fmt.Sprintf("%s-%d", req.GetAccountId(), time.Now().UnixMilli()),
		"$mcc":             req.GetMerchantCategory(),
	}

	payload, err := json.Marshal(body)
	if err != nil {
		log.Printf("sift: marshal: %v", err)
		return ExternalResult{Provider: "sift", Err: err}
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.sift.com/v205/events",
		bytes.NewReader(payload))
	if err != nil {
		log.Printf("sift: build request: %v", err)
		return ExternalResult{Provider: "sift", Err: err}
	}
	httpReq.Header.Set("Content-Type", "application/json")

	start := time.Now()
	resp, err := externalClient.Do(httpReq)
	dur := time.Since(start)
	if err != nil {
		log.Printf("sift: %v", err)
		metrics.ObserveExternal("sift", 0, dur)
		return ExternalResult{Provider: "sift", Err: err}
	}
	resp.Body.Close()
	log.Printf("sift: status %d", resp.StatusCode)
	metrics.ObserveExternal("sift", resp.StatusCode, dur)
	return ExternalResult{Provider: "sift", Status: resp.StatusCode}
}

func callMaxMind(ctx context.Context, req *fraudv1.TransactionRequest) ExternalResult {
	accountID := envOrDefault("MAXMIND_ACCOUNT_ID", "000000")
	licenseKey := envOrDefault("MAXMIND_LICENSE_KEY", "placeholder_maxmind_key")

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
		return ExternalResult{Provider: "maxmind", Err: err}
	}

	httpReq, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://minfraud.maxmind.com/minfraud/v2.0/score",
		bytes.NewReader(payload))
	if err != nil {
		log.Printf("maxmind: build request: %v", err)
		return ExternalResult{Provider: "maxmind", Err: err}
	}
	httpReq.Header.Set("Content-Type", "application/json")
	httpReq.SetBasicAuth(accountID, licenseKey)

	start := time.Now()
	resp, err := externalClient.Do(httpReq)
	dur := time.Since(start)
	if err != nil {
		log.Printf("maxmind: %v", err)
		metrics.ObserveExternal("maxmind", 0, dur)
		return ExternalResult{Provider: "maxmind", Err: err}
	}
	resp.Body.Close()
	log.Printf("maxmind: status %d", resp.StatusCode)
	metrics.ObserveExternal("maxmind", resp.StatusCode, dur)
	return ExternalResult{Provider: "maxmind", Status: resp.StatusCode}
}
