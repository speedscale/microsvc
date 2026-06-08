import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';

const ANTHROPIC_API_KEY = process.env.AI_API_KEY || '';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const XAI_API_KEY = process.env.XAI_API_KEY || '';
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY || '';

const SYSTEM_PROMPT = 'You are a helpful banking assistant for Apex Banking. Answer questions about the user\'s accounts and transactions. Be concise and professional.';

interface ProviderConfig {
  name: string;
  envKey: string;
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

async function callOpenAICompatible(
  apiKey: string,
  baseUrl: string,
  model: string,
  providerName: string,
  message: string,
  accountContext?: string,
) {
  const userContent = accountContext
    ? `User context: ${accountContext}\n\nQuestion: ${message}`
    : message;

  const response = await fetch(baseUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      max_completion_tokens: 1024,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userContent },
      ],
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    console.error(`${providerName} API error:`, response.status, errorBody);
    throw new Error(`${providerName} returned ${response.status}`);
  }

  const data = await response.json();
  return {
    message: data.choices?.[0]?.message?.content || 'No response generated.',
    model: data.model || model,
    provider: providerName,
  };
}

async function callOpenAI(message: string, accountContext?: string) {
  return callOpenAICompatible(
    OPENAI_API_KEY,
    'https://api.openai.com/v1/chat/completions',
    'gpt-4o-mini',
    'openai',
    message,
    accountContext,
  );
}

async function callXAI(message: string, accountContext?: string) {
  return callOpenAICompatible(
    XAI_API_KEY,
    'https://api.x.ai/v1/chat/completions',
    'grok-3-mini',
    'xai',
    message,
    accountContext,
  );
}

async function callOpenRouter(message: string, accountContext?: string) {
  return callOpenAICompatible(
    OPENROUTER_API_KEY,
    'https://openrouter.ai/api/v1/chat/completions',
    'mistralai/mistral-small-3.2-24b-instruct',
    'openrouter',
    message,
    accountContext,
  );
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

const API_KEYS: Record<string, string> = {
  anthropic: ANTHROPIC_API_KEY,
  openai: OPENAI_API_KEY,
  gemini: GEMINI_API_KEY,
  xai: XAI_API_KEY,
  openrouter: OPENROUTER_API_KEY,
};

const providers: Record<string, ProviderConfig> = {
  anthropic: { name: 'Anthropic Claude', envKey: 'AI_API_KEY', call: callAnthropic },
  openai: { name: 'OpenAI GPT', envKey: 'OPENAI_API_KEY', call: callOpenAI },
  gemini: { name: 'Google Gemini', envKey: 'GEMINI_API_KEY', call: callGemini },
  xai: { name: 'xAI Grok', envKey: 'XAI_API_KEY', call: callXAI },
  openrouter: { name: 'OpenRouter', envKey: 'OPENROUTER_API_KEY', call: callOpenRouter },
};

export async function GET() {
  const available = Object.entries(providers)
    .filter(([key]) => !!API_KEYS[key])
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

    const apiKey = API_KEYS[providerKey] || '';
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
