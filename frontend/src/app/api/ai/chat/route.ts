import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';

const AI_SERVICE_URL = process.env.AI_SERVICE_URL || 'http://banking-ai:8080';

export async function GET() {
  try {
    const res = await fetch(`${AI_SERVICE_URL}/api/providers`);
    const data = await res.json();
    return NextResponse.json(data);
  } catch {
    return NextResponse.json({ providers: [] });
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    if (!body.message || typeof body.message !== 'string') {
      return NextResponse.json({ error: 'Message is required' }, { status: 400 });
    }

    const res = await fetch(`${AI_SERVICE_URL}/api/chat`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    const data = await res.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error('AI service proxy error:', error);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
