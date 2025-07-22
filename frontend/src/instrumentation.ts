/*
 * OpenTelemetry instrumentation for Next.js frontend
 * This file is automatically loaded by Next.js when the experimental.instrumentationHook is enabled
 */

import { NodeSDK } from '@opentelemetry/sdk-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-otlp-http';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';

let sdk: NodeSDK | undefined;

// Register the SDK
export async function register() {
  console.log('🔍 Registering OpenTelemetry instrumentation for frontend...');
  console.log('OTEL_EXPORTER_OTLP_ENDPOINT:', process.env.OTEL_EXPORTER_OTLP_ENDPOINT);
  console.log('OTEL_SERVICE_NAME:', process.env.OTEL_SERVICE_NAME);
  
  try {
    // Initialize the OpenTelemetry SDK
    sdk = new NodeSDK({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'frontend',
        [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
        [SemanticResourceAttributes.SERVICE_NAMESPACE]: process.env.OTEL_RESOURCE_ATTRIBUTES?.split('=')[1] || 'banking-app',
      }),
      traceExporter: new OTLPTraceExporter({
        url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://jaeger:4318/v1/traces',
      }),
      instrumentations: [
        getNodeAutoInstrumentations({
          // Disable some instrumentations that might not be needed for frontend
          '@opentelemetry/instrumentation-fs': {
            enabled: false,
          },
          '@opentelemetry/instrumentation-dns': {
            enabled: false,
          },
        }),
      ],
    });

    sdk.start();
    console.log('✅ OpenTelemetry instrumentation registered successfully');
  } catch (error) {
    console.error('❌ Error registering OpenTelemetry instrumentation:', error);
  }
}

// Gracefully shutdown the SDK on process exit
process.on('SIGTERM', () => {
  console.log('🔄 Shutting down OpenTelemetry SDK...');
  sdk?.shutdown()
    .then(() => console.log('✅ OpenTelemetry SDK shutdown successfully'))
    .catch((error) => console.error('❌ Error shutting down OpenTelemetry SDK:', error))
    .finally(() => process.exit(0));
});