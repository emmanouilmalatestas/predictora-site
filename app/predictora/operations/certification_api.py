import datetime
from typing import Dict, Any

def load_environment_suite():
    from app.suites.environment_suite import EnvironmentSuite
    return EnvironmentSuite

def load_billing_suite():
    from app.suites.billing_suite import BillingSuite
    return BillingSuite

def load_runtime_suite():
    from app.suites.runtime_suite import RuntimeSuite
    return RuntimeSuite

def load_replay_suite():
    from app.suites.replay_suite import ReplaySuite
    return ReplaySuite

def load_chaos_suite():
    from app.suites.chaos_suite import ChaosCertificationSuite
    return ChaosCertificationSuite


def run_all_suites() -> Dict[str, Any]:
    EnvironmentSuite = load_environment_suite()
    BillingSuite = load_billing_suite()
    RuntimeSuite = load_runtime_suite()
    ReplaySuite = load_replay_suite()
    ChaosSuite = load_chaos_suite()

    env = EnvironmentSuite().run()
    billing = BillingSuite().run()
    runtime = RuntimeSuite().run()
    replay = ReplaySuite().run()
    chaos = ChaosSuite().run()

    suites = {
        "environment": {
            "name": env.name,
            "score": env.score,
            "status": env.status,
            "checks": [c.__dict__ for c in env.checks],
        },
        "billing": {
            "name": billing.name,
            "score": billing.score,
            "status": billing.status,
            "checks": [c.__dict__ for c in billing.checks],
        },
        "runtime": {
            "name": runtime.name,
            "score": runtime.score,
            "status": runtime.status,
            "checks": [c.__dict__ for c in runtime.checks],
        },
        "replay": {
            "name": replay.name,
            "score": replay.score,
            "status": replay.status,
            "checks": [c.__dict__ for c in replay.checks],
        },
        "chaos": {
            "name": chaos.name,
            "score": chaos.score,
            "status": chaos.status,
            "checks": [c.__dict__ for c in chaos.checks],
        },
    }

    scores = [
        env.score,
        billing.score,
        runtime.score,
        replay.score,
        chaos.score,
    ]
    overall_score = sum(scores) / len(scores) if scores else 0.0

    return {
        "PredictoraOS Enterprise Certification": {
            "version": "2.0",
            "overall_score": overall_score * 100.0,
            "level": "Enterprise+ (Bank Grade)" if overall_score >= 0.95 else "Not Certified",
            "suites": suites,
            "started_at": datetime.datetime.utcnow().isoformat() + "Z",
        }
    }
