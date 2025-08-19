/*
 * OpenTelemetry instrumentation for Next.js frontend
 * This file is automatically loaded by Next.js when the experimental.instrumentationHook is enabled
 * Note: This only runs on the server side during SSR/API routes, not in the browser
 */

// Type declaration for EdgeRuntime
declare global {
  const EdgeRuntime: string | undefined;
}

// Conditional logging based on OTEL_LOG_LEVEL environment variable
const isDebugMode = process.env.OTEL_LOG_LEVEL === 'DEBUG';

function log(message: string, ...args: unknown[]) {
  if (isDebugMode) {
    console.log(message, ...args);
  }
}

// Register the SDK - only runs on the server side
export async function register() {
  // Only initialize on server side to avoid bundling issues with browser
  if (typeof window !== 'undefined') {
    return;
  }
  
  // Check if we're in Edge Runtime (middleware) - skip instrumentation
  if (typeof EdgeRuntime !== 'undefined') {
    log('🔧 EdgeRuntime detected, but continuing with Node.js instrumentation...');
    // Don't return - continue with instrumentation even in Edge Runtime
  }
  
  // Check if we're in a Node.js environment
  if (typeof process === 'undefined' || !process.versions?.node) {
    log('🔍 Skipping OpenTelemetry instrumentation - not in Node.js environment');
    return;
  }
  
  log('🔍 Registering OpenTelemetry instrumentation for frontend server...');
  log('🔧 Environment variables:');
  log('  - OTEL_SERVICE_NAME:', process.env.OTEL_SERVICE_NAME);
  log('  - OTEL_EXPORTER_OTLP_ENDPOINT:', process.env.OTEL_EXPORTER_OTLP_ENDPOINT);
  log('  - OTEL_RESOURCE_ATTRIBUTES:', process.env.OTEL_RESOURCE_ATTRIBUTES);
  log('  - NODE_ENV:', process.env.NODE_ENV);
  
  // Always log the basic startup message
  console.log('🚀 Starting OpenTelemetry instrumentation for frontend service');
  
  try {
    // Skip OTEL instrumentation during build to avoid type compatibility issues
    if (process.env.NODE_ENV === 'production' && !process.env.OTEL_SERVICE_NAME) {
      log('🔍 Skipping OpenTelemetry instrumentation during build');
      return;
    }

    // Use a minimal approach that avoids NodeSDK to prevent bundling issues
    const { NodeTracerProvider } = await import('@opentelemetry/sdk-trace-node');
    const { SimpleSpanProcessor } = await import('@opentelemetry/sdk-trace-base');
    const { OTLPTraceExporter } = await import('@opentelemetry/exporter-trace-otlp-http');
    const { Resource } = await import('@opentelemetry/resources');
    const { SemanticResourceAttributes } = await import('@opentelemetry/semantic-conventions');
    const { trace, context, propagation } = await import('@opentelemetry/api');
    
    log('🔧 OpenTelemetry packages loaded successfully');
    
    // Note: W3C Trace Context propagator is set by default in OpenTelemetry
    // No need to explicitly set it as it's the default propagator
    
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

    log('🔧 OTLP Exporter configured with URL:', process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://localhost:4318/v1/traces');
    
    // Test OTLP exporter connectivity
    log('🔧 Testing OTLP exporter connectivity...');
    try {
      // Create a test span to export
      const testTracer = trace.getTracer('connectivity-test');
      const testSpan = testTracer.startSpan('connectivity-test');
      testSpan.setAttribute('test.connectivity', 'true');
      testSpan.end();
      
      // Force export with error handling
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      otlpExporter.export([testSpan as any], (result) => {
        log('🔧 OTLP Export test result:', result);
        if (result.code !== 0) {
          log('❌ OTLP Export failed:', result);
        } else {
          log('✅ OTLP Export test successful');
        }
      });
    } catch (error) {
      log('❌ OTLP Export test error:', error);
    }

    // Add ConsoleSpanExporter for debugging only in debug mode
    if (isDebugMode) {
      const { ConsoleSpanExporter } = await import('@opentelemetry/sdk-trace-base');
      const consoleExporter = new ConsoleSpanExporter();
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      tracerProvider.addSpanProcessor(new SimpleSpanProcessor(consoleExporter as any));
    }
    
    // Add OTLP exporter
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    tracerProvider.addSpanProcessor(new SimpleSpanProcessor(otlpExporter as any));
    
    log('🔧 Console and OTLP span processors added to tracer provider');
    
    // Register the tracer provider
    tracerProvider.register();
    trace.setGlobalTracerProvider(tracerProvider);

    log('✅ OpenTelemetry instrumentation registered successfully for frontend server');
    log('🔧 Service name:', process.env.OTEL_SERVICE_NAME || 'frontend');
    log('🔧 Service namespace:', process.env.OTEL_RESOURCE_ATTRIBUTES?.split('=')[1] || 'banking-app');

    // Gracefully shutdown the tracer provider on process exit
    process.on('SIGTERM', () => {
      log('🔄 Shutting down OpenTelemetry tracer provider...');
      tracerProvider.shutdown()
        .then(() => log('✅ OpenTelemetry tracer provider shutdown successfully'))
        .catch((error) => log('❌ Error shutting down OpenTelemetry tracer provider:', error))
        .finally(() => process.exit(0));
    });

    // Test the tracer by creating a simple span
    const testTracer = trace.getTracer('frontend-test');
    const testSpan = testTracer.startSpan('test-span');
    testSpan.setAttribute('test.attribute', 'test-value');
    testSpan.end();
    log('🔧 Test span created and ended');

    // Create a utility function to get current trace context for API calls
    const getCurrentTraceContext = () => {
      const currentContext = context.active();
      const carrier: Record<string, string> = {};
      propagation.inject(currentContext, carrier);
      return carrier['traceparent'] || null;
    };

    // Expose trace context utilities to process.env for API client access
    // This is a safer approach than using global in browser environments
    if (typeof process !== 'undefined') {
      // Extend process with our trace utilities
      interface ProcessWithOtelUtils extends NodeJS.Process {
        __OTEL_TRACE_UTILS__?: {
          getCurrentTraceContext: () => string | null;
          createSpan: (name: string, attributes?: Record<string, string | number | boolean>) => unknown;
        };
      }
      (process as ProcessWithOtelUtils).__OTEL_TRACE_UTILS__ = {
        getCurrentTraceContext,
        createSpan: (name: string, attributes?: Record<string, string | number | boolean>) => {
          const tracer = trace.getTracer('frontend-api');
          const span = tracer.startSpan(name);
          if (attributes) {
            Object.entries(attributes).forEach(([key, value]) => {
              span.setAttribute(key, value);
            });
          }
          return span;
        }
      };
    }
  } catch (error) {
    console.error('❌ Error registering OpenTelemetry instrumentation:', error);
  }
}