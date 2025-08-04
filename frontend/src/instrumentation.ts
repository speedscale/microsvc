/*
 * OpenTelemetry instrumentation for Next.js frontend
 * This file is automatically loaded by Next.js when the experimental.instrumentationHook is enabled
 * Note: This only runs on the server side during SSR/API routes, not in the browser
 */

// Type declaration for EdgeRuntime
declare global {
  const EdgeRuntime: string | undefined;
}

// Register the SDK - only runs on the server side
export async function register() {
  // Only initialize on server side to avoid bundling issues with browser
  if (typeof window !== 'undefined') {
    return;
  }
  
  // Check if we're in Edge Runtime (middleware) - skip instrumentation
  if (typeof EdgeRuntime !== 'undefined') {
    console.log('🔧 EdgeRuntime detected, but continuing with Node.js instrumentation...');
    // Don't return - continue with instrumentation even in Edge Runtime
  }
  
  // Check if we're in a Node.js environment
  if (typeof process === 'undefined' || !process.versions?.node) {
    console.log('🔍 Skipping OpenTelemetry instrumentation - not in Node.js environment');
    return;
  }
  
  console.log('🔍 Registering OpenTelemetry instrumentation for frontend server...');
  console.log('🔧 Environment variables:');
  console.log('  - OTEL_SERVICE_NAME:', process.env.OTEL_SERVICE_NAME);
  console.log('  - OTEL_EXPORTER_OTLP_ENDPOINT:', process.env.OTEL_EXPORTER_OTLP_ENDPOINT);
  console.log('  - OTEL_RESOURCE_ATTRIBUTES:', process.env.OTEL_RESOURCE_ATTRIBUTES);
  console.log('  - NODE_ENV:', process.env.NODE_ENV);
  
  try {
    // Skip OTEL instrumentation during build to avoid type compatibility issues
    if (process.env.NODE_ENV === 'production' && !process.env.OTEL_SERVICE_NAME) {
      console.log('🔍 Skipping OpenTelemetry instrumentation during build');
      return;
    }

    // Use a minimal approach that avoids NodeSDK to prevent bundling issues
    const { NodeTracerProvider } = await import('@opentelemetry/sdk-trace-node');
    const { SimpleSpanProcessor } = await import('@opentelemetry/sdk-trace-base');
    const { OTLPTraceExporter } = await import('@opentelemetry/exporter-trace-otlp-http');
    const { Resource } = await import('@opentelemetry/resources');
    const { SemanticResourceAttributes } = await import('@opentelemetry/semantic-conventions');
    const { trace } = await import('@opentelemetry/api');
    
    console.log('🔧 OpenTelemetry packages loaded successfully');
    
    // Create a custom tracer provider for Next.js
    const tracerProvider = new NodeTracerProvider({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || 'frontend',
        [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
        [SemanticResourceAttributes.SERVICE_NAMESPACE]: process.env.OTEL_RESOURCE_ATTRIBUTES?.split('=')[1] || 'banking-app',
      }),
    });

    // Configure OTLP exporter with error handling
    const otlpExporter = new OTLPTraceExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces',
    });

    console.log('🔧 OTLP Exporter configured with URL:', process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces');
    
    // Test OTLP exporter connectivity
    console.log('🔧 Testing OTLP exporter connectivity...');
    try {
      // Create a test span to export
      const testTracer = trace.getTracer('connectivity-test');
      const testSpan = testTracer.startSpan('connectivity-test');
      testSpan.setAttribute('test.connectivity', 'true');
      testSpan.end();
      
      // Force export with error handling
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      otlpExporter.export([testSpan as any], (result) => {
        console.log('🔧 OTLP Export test result:', result);
        if (result.code !== 0) {
          console.error('❌ OTLP Export failed:', result);
        } else {
          console.log('✅ OTLP Export test successful');
        }
      });
    } catch (error) {
      console.error('❌ OTLP Export test error:', error);
    }

    // Add ConsoleSpanExporter for debugging (as suggested in OpenTelemetry troubleshooting guide)
    const { ConsoleSpanExporter } = await import('@opentelemetry/sdk-trace-base');
    const consoleExporter = new ConsoleSpanExporter();
    
    // Add both console and OTLP exporters for debugging
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    tracerProvider.addSpanProcessor(new SimpleSpanProcessor(consoleExporter as any));
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    tracerProvider.addSpanProcessor(new SimpleSpanProcessor(otlpExporter as any));
    
    console.log('🔧 Console and OTLP span processors added to tracer provider');
    
    // Register the tracer provider
    tracerProvider.register();
    trace.setGlobalTracerProvider(tracerProvider);

    console.log('✅ OpenTelemetry instrumentation registered successfully for frontend server');
    console.log('🔧 Service name:', process.env.OTEL_SERVICE_NAME || 'frontend');
    console.log('🔧 Service namespace:', process.env.OTEL_RESOURCE_ATTRIBUTES?.split('=')[1] || 'banking-app');

    // Gracefully shutdown the tracer provider on process exit
    process.on('SIGTERM', () => {
      console.log('🔄 Shutting down OpenTelemetry tracer provider...');
      tracerProvider.shutdown()
        .then(() => console.log('✅ OpenTelemetry tracer provider shutdown successfully'))
        .catch((error) => console.error('❌ Error shutting down OpenTelemetry tracer provider:', error))
        .finally(() => process.exit(0));
    });

    // Test the tracer by creating a simple span
    const testTracer = trace.getTracer('frontend-test');
    const testSpan = testTracer.startSpan('test-span');
    testSpan.setAttribute('test.attribute', 'test-value');
    testSpan.end();
    console.log('🔧 Test span created and ended');

    // Expose trace context to window for API client
    if (typeof window !== 'undefined') {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (window as any).__OTEL_TRACE_CONTEXT__ = null;
      
      // Update trace context when new spans are created
      const originalStartSpan = testTracer.startSpan;
      testTracer.startSpan = function(name: string, options?: Parameters<typeof originalStartSpan>[1]) {
        const span = originalStartSpan.call(this, name, options);
        const context = span.spanContext();
        if (context.traceId && context.spanId) {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          (window as any).__OTEL_TRACE_CONTEXT__ = `00-${context.traceId}-${context.spanId}-01`;
        }
        return span;
      };
    }
  } catch (error) {
    console.error('❌ Error registering OpenTelemetry instrumentation:', error);
  }
}