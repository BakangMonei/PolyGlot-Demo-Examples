import { Kafka, logLevel } from "kafkajs";

async function main() {
  const broker = process.env.KAFKA_BROKER ?? "localhost:9092";
  const topic = process.env.KAFKA_TOPIC ?? "transactions.created";
  const correlationId = process.env.CORRELATION_ID ?? crypto.randomUUID();

  const kafka = new Kafka({ clientId: "producer-ts", brokers: [broker], logLevel: logLevel.NOTHING });
  const producer = kafka.producer();
  await producer.connect();
  await producer.send({
    topic,
    messages: [
      {
        headers: { "x-correlation-id": correlationId },
        value: JSON.stringify({
          event_type: "transactions.created",
          transaction_id: `demo-${Date.now()}`,
          account_id: "demo-checking-001",
          amount_minor: 1,
          occurred_at: new Date().toISOString(),
          correlation_id: correlationId,
        }),
      },
    ],
  });
  await producer.disconnect();
  console.log(`published to ${topic}`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
