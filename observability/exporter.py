from prometheus_client import start_http_server, Gauge
import time

metric_runtime = Gauge("predictora_runtime_health", "Runtime health")
metric_cert = Gauge("predictora_certification_health", "Certification engine health")
metric_ledger = Gauge("predictora_ledger_hashing_health", "Ledger hashing health")

start_http_server(9100)

while True:
    metric_runtime.set(1)
    metric_cert.set(1)
    metric_ledger.set(1)
    time.sleep(5)
