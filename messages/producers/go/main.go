package main

import (
	"context"
	"encoding/json"
	"log"
	"os"
	"time"

	"github.com/segmentio/kafka-go"
)

func main() {
	broker := os.Getenv("KAFKA_BROKER")
	if broker == "" {
		broker = "localhost:9092"
	}
	topic := os.Getenv("KAFKA_TOPIC")
	if topic == "" {
		topic = "transactions.created"
	}
	w := &kafka.Writer{
		Addr:     kafka.TCP(broker),
		Topic:    topic,
		Balancer: &kafka.LeastBytes{},
	}
	defer w.Close()

	payload, _ := json.Marshal(map[string]any{
		"event_type":      topic,
		"transaction_id":  "demo-tx",
		"account_id":      "demo-checking-001",
		"amount_minor":    1,
		"occurred_at":     time.Now().UTC().Format(time.RFC3339Nano),
		"correlation_id":  os.Getenv("CORRELATION_ID"),
	})
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	err := w.WriteMessages(ctx, kafka.Message{
		Headers: []kafka.Header{{Key: "x-correlation-id", Value: []byte(os.Getenv("CORRELATION_ID"))}},
		Value:   payload,
	})
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("published to %s", topic)
}
