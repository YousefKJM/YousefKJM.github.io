"""Read Intune diagnostic logs from Azure Event Hubs, de-duplicate, forward as JSON lines."""
import hashlib, json, os
from azure.eventhub import EventHubConsumerClient

seen = set()                                   # use Redis / a DB with a TTL in production

def dedup_key(rec: dict) -> str:
    props = rec.get("properties") or {}
    if isinstance(props, str):
        props = json.loads(props)
    # audit records carry a unique AuditEventId; fall back to a content hash
    return props.get("AuditEventId") or hashlib.sha256(json.dumps(rec, sort_keys=True).encode()).hexdigest()

def forward(rec: dict):
    print(json.dumps({"source": "intune", "category": rec.get("category"),
                      "time": rec.get("time"), "operation": rec.get("operationName"),
                      "identity": rec.get("identity"), "raw": rec}))   # -> replace with your SIEM's HTTP/syslog input

def on_event(partition_context, event):
    for rec in json.loads(event.body_as_str())["records"]:       # Azure Monitor wraps rows in "records"
        key = dedup_key(rec)
        if key in seen:
            continue                                              # Intune can re-send up to 100% of a day's data
        seen.add(key)
        forward(rec)
    partition_context.update_checkpoint(event)

client = EventHubConsumerClient.from_connection_string(
    os.environ["EH_CONN"], consumer_group="siem", eventhub_name="insights-logs-auditlogs")
with client:
    client.receive(on_event=on_event, starting_position="-1")
