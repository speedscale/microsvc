import { NextRequest, NextResponse } from 'next/server';

// Force Node.js runtime for OpenTelemetry compatibility
export const runtime = 'nodejs';

const API_GATEWAY_URL = process.env.API_GATEWAY_URL || 'http://localhost:8080';

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const authHeader = request.headers.get('authorization');
    
    const resolvedParams = await params;
    const response = await fetch(`${API_GATEWAY_URL}/api/accounts/${resolvedParams.id}/balance`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        ...(authHeader && { 'Authorization': authHeader }),
      },
    });

    const data = await response.json();
    
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Get account balance proxy error:', error);
    return NextResponse.json(
      { message: 'Internal server error' },
      { status: 500 }
    );
  }
} 