# Kafka SASL overlay

This overlay runs the banking app with Kafka client authentication enabled.
It keeps the base app unchanged and switches only the Kafka listener plus the
transactions and notification clients.

```bash
kubectl apply -k kubernetes/overlays/kafka-sasl
```

The demo uses `SASL_PLAINTEXT` with the `PLAIN` mechanism and non-production
credentials in `banking-kafka-sasl`. Use it for capture and replay testing of
authenticated Kafka traffic, not for production.
