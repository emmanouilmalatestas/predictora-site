from predictora.usage.features import feature_for
from predictora.usage_engine import UsageEngine

def log_api_usage(request, tenant_id, plan_tier):
    class ApiUsageEvent:
        type = f"api.{request.method}:{request.url.path}"
        payload = { 'feature': feature_for(request.url.path),"query": dict(request.query_params)}

        def to_command(self):
            from predictora.core.commands import Command
            return Command(
                type=self.type,
                tenant_id=tenant_id,
                payload=self.payload,
            )

    UsageEngine().record_usage(
        tenant_id=tenant_id,
        plan_tier=plan_tier,
        usage_event=ApiUsageEvent(),
    )
