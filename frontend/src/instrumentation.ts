/*
 * OpenTelemetry instrumentation for Next.js frontend
 * This file is automatically loaded by Next.js when the experimental.instrumentationHook is enabled
 * Note: This only runs on the server side during SSR/API routes, not in the browser
 */

// Register the SDK - only runs on the server side
export async function register() {
  // Only initialize on server side to avoid bundling issues with browser
  if (typeof window !== 'undefined') {
    return;
  }
  
  console.log('🔍 Registering OpenTelemetry instrumentation for frontend server...');
  
  try {
    // Skip OTEL instrumentation during build to avoid type compatibility issues
    if (process.env.NODE_ENV === 'production' && !process.env.OTEL_SERVICE_NAME) {
      console.log('🔍 Skipping OpenTelemetry instrumentation during build');
      return;
    }

    // Use a minimal approach that avoids NodeSDK to prevent bundling issues
    const { NodeTracerProvider } = await import('@opentelemetry/sdk-trace-node');
    const { BatchSpanProcessor } = await import('@opentelemetry/sdk-trace-base');
    const { OTLPTraceExporter } = await import('@opentelemetry/exporter-otlp-http');
    const { Resource } = await import('@opentelemetry/resources');
    const { SemanticResourceAttributes } = await import('@opentelemetry/semantic-conventions');
    const { trace } = await import('@opentelemetry/api');
    
    // Create a custom tracer provider for Next.js
    const tracerProvider = new NodeTracerProvider({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'frontend',
        [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
        [SemanticResourceAttributes.SERVICE_NAMESPACE]: process.env.OTEL_RESOURCE_ATTRIBUTES?.split('=')[1] || 'banking-app',
      }),
    });

    // Configure OTLP exporter
    const otlpExporter = new OTLPTraceExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces',
    });

    // Add span processor with type assertion to bypass version conflicts
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    tracerProvider.addSpanProcessor(new BatchSpanProcessor(otlpExporter as any));
    
    // Register the tracer provider
    tracerProvider.register();
    trace.setGlobalTracerProvider(tracerProvider);

    console.log('✅ OpenTelemetry instrumentation registered successfully for frontend server');

    // Gracefully shutdown the tracer provider on process exit
    process.on('SIGTERM', () => {
      console.log('🔄 Shutting down OpenTelemetry tracer provider...');
      tracerProvider.shutdown()
        .then(() => console.log('✅ OpenTelemetry tracer provider shutdown successfully'))
        .catch((error) => console.error('❌ Error shutting down OpenTelemetry tracer provider:', error))
        .finally(() => process.exit(0));
    });
  } catch (error) {
    console.error('❌ Error registering OpenTelemetry instrumentation:', error);
  }
}