#!/bin/bash

curl http://127.0.0.1:8100/runtime/health && \
curl -X POST http://127.0.0.1:8100/knowledge/create \
  -H "Content-Type: application/json" \
  -d '{"item":"health_test"}' && \
curl -X POST http://127.0.0.1:8100/decision/run \
  -H "Content-Type: application/json" \
  -d '{"decision_name":"health_decision","payload":{"x":1}}' && \
curl -X POST http://127.0.0.1:8100/automation/fire \
  -H "Content-Type: application/json" \
  -d '{"trigger_name":"health_trigger","payload":{"y":2},"actor_id":"system","tenant_id":"default"}' && \
curl -X POST http://127.0.0.1:8100/replay/run \
  -H "Content-Type: application/json" \
  -d '{"original_run_id":"debfebd9-9c9b-45d8-89b2-0364f2805d88","mode":"exact"}' && \
curl -X POST http://127.0.0.1:8100/compliance/run \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"HEALTH","profile":{"age":30,"country":"CY","segment":"standard"},"documents":[{"type":"id","valid":true}],"transactions":[{"amount":100,"country":"CY"}],"mode":"full"}'
