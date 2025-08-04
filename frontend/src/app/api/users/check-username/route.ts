import { NextRequest, NextResponse } from 'next/server';

// Force Node.js runtime for OpenTelemetry compatibility
export const runtime = 'nodejs';

const API_GATEWAY_URL = process.env.API_GATEWAY_URL || 'http://localhost:8080';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const username = searchParams.get('username');
    
    if (!username) {
      return NextResponse.json(
        { message: 'Username parameter is required' },
        { status: 400 }
      );
    }
    
    const response = await fetch(`${API_GATEWAY_URL}/api/users/check-username?username=${username}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const data = await response.json();
    
    return NextResponse.json(data, { status: response.status });
  } catch (error) {
    console.error('Check username proxy error:', error);
    return NextResponse.json(
      { message: 'Internal server error' },
      { status: 500 }
    );
  }
} 