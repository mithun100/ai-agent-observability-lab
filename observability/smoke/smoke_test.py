#!/usr/bin/env python3
"""Emit synthetic OTLP trace, metric, and log for backend smoke validation."""

import logging
import os
import time

from opentelemetry import _logs, metrics, trace
from opentelemetry.exporter.otlp.proto.grpc._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor


resource = Resource.create(
    {
        "service.name": os.getenv("OTEL_SERVICE_NAME", "travel-planner-smoke"),
        "service.version": os.getenv("OTEL_SERVICE_VERSION", "0.1.0"),
        "deployment.environment": os.getenv("OTEL_DEPLOYMENT_ENVIRONMENT", "smoke"),
    }
)

trace_provider = TracerProvider(resource=resource)
trace_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(trace_provider)

metric_reader = PeriodicExportingMetricReader(OTLPMetricExporter(), export_interval_millis=5000)
metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))

logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
_logs.set_logger_provider(logger_provider)

tracer = trace.get_tracer("smoke-test")
meter = metrics.get_meter("smoke-test")
counter = meter.create_counter("smoke_test_counter")

logging.basicConfig(level=logging.INFO)
app_logger = logging.getLogger("smoke-test")

with tracer.start_as_current_span("smoke.test.span") as span:
    span.set_attribute("smoke.backend", os.getenv("OBSERVABILITY_BACKEND", "unknown"))
    span.set_attribute("gen_ai.operation.name", "smoke_test")
    counter.add(1, {"smoke.backend": os.getenv("OBSERVABILITY_BACKEND", "unknown")})
    app_logger.info("smoke test log event for backend validation")

# Give asynchronous exporters time to flush.
time.sleep(6)
print("Smoke telemetry emitted. Validate via backend APIs or collector logs.")
