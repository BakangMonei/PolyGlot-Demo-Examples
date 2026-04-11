#!/usr/bin/env python3
"""Minimal Kafka producer (JSON payloads aligned with shared/schemas)."""
import json
import os
import time
import uuid

from kafka import KafkaProducer

def main() -> None:
    broker = os.environ.get("KAFKA_BROKER", "localhost:9092")
    topic = os.environ.get("KAFKA_TOPIC", "transactions.created")
    cid = os.environ.get("CORRELATION_ID", str(uuid.uuid4()))
    producer = KafkaProducer(
        bootstrap_servers=[broker],
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
    )
    payload = {
        "event_type": "transactions.created",
        "transaction_id": f"demo-{int(time.time())}",
        "account_id": "demo-checking-001",
        "amount_minor": 1,
        "occurred_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "correlation_id": cid,
    }
    producer.send(topic, value=payload, headers=[("x-correlation-id", cid.encode())])
    producer.flush()
    print(f"published to {topic} correlation={cid}")


if __name__ == "__main__":
    main()
