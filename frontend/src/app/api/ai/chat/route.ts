import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';

const AI_API_KEY = process.env.AI_API_KEY || '';
const ANTHROPIC_API_URL = process.env.ANTHROPIC_API_URL || 'https://api.anthropic.com/v1/messages';
const MODEL = 'claude-sonnet-4-20250514';
const SYSTEM_PROMPT = 'You are a helpful banking assistant. Answer questions about the user\'s accounts and transactions. Be concise.';

export async function POST(request: NextRequest) {
  try {
    const { message, accountContext } = await request.json();

    if (!message || typeof message !== 'string') {
      return NextResponse.json(
        { error: 'Message is required' },
        { status: 400 }
      );
    }

    if (!AI_API_KEY) {
      return NextResponse.json(
        { error: 'AI service not configured' },
        { status: 503 }
      );
    }

    const userContent = accountContext
      ? `User context: ${JSON.stringify(accountContext)}\n\nQuestion: ${message}`
      : message;

    const response = await fetch(ANTHROPIC_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AI_API_KEY,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages: [
          { role: 'user', content: userContent }
        ],
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      console.error('Anthropic API error:', response.status, errorBody);
      return NextResponse.json(
        { error: 'AI service unavailable' },
        { status: 503 }
      );
    }

    const data = await response.json();
    const assistantMessage = data.content?.[0]?.text || 'No response generated.';

    return NextResponse.json({
      message: assistantMessage,
      model: data.model,
      usage: data.usage,
    });
  } catch (error) {
    console.error('AI chat error:', error);
    return NextResponse.json(
      { error: 'AI service unavailable' },
      { status: 503 }
    );
  }
}
