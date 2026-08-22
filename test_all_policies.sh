#!/bin/bash
sleep 2

echo "=== POLICY v2 ==="
curl -X POST http://127.0.0.1:8100/compliance/run \
  -H "Content-Type: application/json" \
  -d '{
        "policy_version": "policy_v2",
        "customer_id": "TEST-POLICY-V2",
        "profile": {
            "age": 35,
            "country": "RU",
            "segment": "new_user",
            "name": "Kadyrov"
        },
        "documents": [
            {"type": "id_card", "valid": true}
        ],
        "transactions": [
            {"amount": 7000, "country": "RU"},
            {"amount": 6900, "country": "RU"},
            {"amount": 6800, "country": "RU"}
        ],
        "mode": "full"
      }'

echo ""
echo "=== POLICY v3 (ML-TUNED) ==="
curl -X POST http://127.0.0.1:8100/compliance/run \
  -H "Content-Type: application/json" \
  -d '{
        "policy_version": "policy_v3",
        "customer_id": "TEST-POLICY-V3",
        "profile": {
            "age": 35,
            "country": "RU",
            "segment": "new_user",
            "name": "Kadyrov"
        },
        "documents": [
            {"type": "id_card", "valid": true}
        ],
        "transactions": [
            {"amount": 7000, "country": "RU"},
            {"amount": 6900, "country": "RU"},
            {"amount": 6800, "country": "RU"}
        ],
        "mode": "full"
      }'

echo ""
echo "=== POLICY v2.1 (SEGMENT-ADAPTIVE) ==="
curl -X POST http://127.0.0.1:8100/compliance/run \
  -H "Content-Type: application/json" \
  -d '{
        "policy_version": "policy_v2.1",
        "customer_id": "TEST-POLICY-V2.1",
        "profile": {
            "age": 35,
            "country": "RU",
            "segment": "new_user",
            "name": "Kadyrov"
        },
        "documents": [
            {"type": "id_card", "valid": true}
        ],
        "transactions": [
            {"amount": 7000, "country": "RU"},
            {"amount": 6900, "country": "RU"},
            {"amount": 6800, "country": "RU"}
        ],
        "mode": "full"
      }'

echo ""
echo "=== POLICY v2-enterprise (BANK-GRADE) ==="
curl -X POST http://127.0.0.1:8100/compliance/run \
  -H "Content-Type: application/json" \
  -d '{
        "policy_version": "policy_v2_enterprise",
        "customer_id": "TEST-POLICY-ENTERPRISE",
        "profile": {
            "age": 35,
            "country": "RU",
            "segment": "new_user",
            "name": "Kadyrov"
        },
        "documents": [
            {"type": "id_card", "valid": true}
        ],
        "transactions": [
            {"amount": 7000, "country": "RU"},
            {"amount": 6900, "country": "RU"},
            {"amount": 6800, "country": "RU"}
        ],
        "mode": "full"
      }'
