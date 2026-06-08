import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';

const ANTHROPIC_API_KEY = process.env.AI_API_KEY || '';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';

const SYSTEM_PROMPT = 'You are a helpful banking assistant for Apex Banking. Answer questions about the user\'s accounts and transactions. Be concise and professional.';

interface ProviderConfig {
  name: string;
  call: (message: string, accountContext?: string) => Promise<{ message: string; model: string; provider: string }>;
}

async function callAnthropic(message: string, accountContext?: string) {
  const userContent = accountContext
    ? `User context: ${accountContext}\n\nQuestion: ${message}`
    : message;

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': ANTHROPIC_API_KEY,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: 'claude-sonnet-4-20250514',
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: userContent }],
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error('Anthropic API error:', response.status, errorBody);
    throw new Error(`Anthropic returned ${response.status}`);
  }

  const data = await response.json();
  return {
    message: data.content?.[0]?.text || 'No response generated.',
    model: data.model,
    provider: 'anthropic',
  };
}

async function callOpenAI(message: string, accountContext?: string) {
  const userContent = accountContext
    ? `User context: ${accountContext}\n\nQuestion: ${message}`
    : message;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      max_completion_tokens: 1024,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userContent },
      ],
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error('OpenAI API error:', response.status, errorBody);
    throw new Error(`OpenAI returned ${response.status}`);
  }

  const data = await response.json();
  return {
    message: data.choices?.[0]?.message?.content || 'No response generated.',
    model: data.model,
    provider: 'openai',
  };
}

async function callGemini(message: string, accountContext?: string) {
  const userContent = accountContext
    ? `User context: ${accountContext}\n\nQuestion: ${message}`
    : message;

  const model = 'gemini-2.0-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: SYSTEM_PROMPT }] },
      contents: [{ parts: [{ text: userContent }] }],
      generationConfig: {
        temperature: 0.3,
        maxOutputTokens: 1024,
      },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error('Gemini API error:', response.status, errorBody);
    throw new Error(`Gemini returned ${response.status}`);
  }

  const data = await response.json();
  return {
    message: data.candidates?.[0]?.content?.parts?.[0]?.text || 'No response generated.',
    model: model,
    provider: 'gemini',
  };
}

const providers: Record<string, ProviderConfig> = {
  anthropic: { name: 'Anthropic Claude', call: callAnthropic },
  openai: { name: 'OpenAI GPT', call: callOpenAI },
  gemini: { name: 'Google Gemini', call: callGemini },
};

export async function GET() {
  const available = Object.entries(providers)
    .filter(([key]) => {
      if (key === 'anthropic') return !!ANTHROPIC_API_KEY;
      if (key === 'openai') return !!OPENAI_API_KEY;
      if (key === 'gemini') return !!GEMINI_API_KEY;
      return false;
    })
    .map(([key, config]) => ({ id: key, name: config.name }));

  return NextResponse.json({ providers: available });
}

export async function POST(request: NextRequest) {
  try {
    const { message, accountContext, provider: requestedProvider } = await request.json();

    if (!message || typeof message !== 'string') {
      return NextResponse.json({ error: 'Message is required' }, { status: 400 });
    }

    const providerKey = requestedProvider || 'anthropic';
    const provider = providers[providerKey];

    if (!provider) {
      return NextResponse.json({ error: `Unknown provider: ${providerKey}` }, { status: 400 });
    }

    const apiKey = providerKey === 'anthropic' ? ANTHROPIC_API_KEY
      : providerKey === 'openai' ? OPENAI_API_KEY
      : providerKey === 'gemini' ? GEMINI_API_KEY
      : '';

    if (!apiKey) {
      return NextResponse.json(
        { error: `${provider.name} is not configured` },
        { status: 503 },
      );
    }

    const contextStr = accountContext ? JSON.stringify(accountContext) : undefined;
    const result = await provider.call(message, contextStr);

    return NextResponse.json(result);
  } catch (error) {
    console.error('AI chat error:', error);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
