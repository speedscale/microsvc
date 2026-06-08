import { NextRequest, NextResponse } from 'next/server';

export const runtime = 'nodejs';

const ANTHROPIC_API_KEY = process.env.AI_API_KEY || '';
const OPENAI_API_KEY = process.env.OPENAI_API_KEY || '';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const XAI_API_KEY = process.env.XAI_API_KEY || '';
const OPENROUTER_API_KEY = process.env.OPENROUTER_API_KEY || '';

const SYSTEM_PROMPT = 'You are a helpful banking assistant for Apex Banking. Answer questions about the user\'s accounts and transactions. Be concise and professional.';

interface ProviderResult {
  provider: string;
  name: string;
  model: string;
  message: string;
  error?: string;
  durationMs: number;
}

async function callAnthropic(message: string, accountContext?: string): Promise<ProviderResult> {
  const t0 = Date.now();
  const userContent = accountContext
    ? `User context: ${accountContext}\n\nQuestion: ${message}`
    : message;

  try {
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
      return { provider: 'anthropic', name: 'Anthropic Claude', model: 'claude-sonnet-4-20250514', message: '', error: `HTTP ${response.status}`, durationMs: Date.now() - t0 };
    }

    const data = await response.json();
    return {
      provider: 'anthropic',
      name: 'Anthropic Claude',
      model: data.model || 'claude-sonnet-4-20250514',
      message: data.content?.[0]?.text || 'No response generated.',
      durationMs: Date.now() - t0,
    };
  } catch (err) {
    return { provider: 'anthropic', name: 'Anthropic Claude', model: 'claude-sonnet-4-20250514', message: '', error: String(err), durationMs: Date.now() - t0 };
  }
}

async function callOpenAICompatible(
  apiKey: string,
  baseUrl: string,
  model: string,
  providerKey: string,
  providerName: string,
  message: string,
  accountContext?: string,
): Promise<ProviderResult> {
  const t0 = Date.now();
  const userContent = accountContext
    ? `User context: ${accountContext}\n\nQuestion: ${message}`
    : message;

  try {
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
      return { provider: providerKey, name: providerName, model, message: '', error: `HTTP ${response.status}`, durationMs: Date.now() - t0 };
    }

    const data = await response.json();
    return {
      provider: providerKey,
      name: providerName,
      model: data.model || model,
      message: data.choices?.[0]?.message?.content || 'No response generated.',
      durationMs: Date.now() - t0,
    };
  } catch (err) {
    return { provider: providerKey, name: providerName, model, message: '', error: String(err), durationMs: Date.now() - t0 };
  }
}

async function callGemini(message: string, accountContext?: string): Promise<ProviderResult> {
  const t0 = Date.now();
  const userContent = accountContext
    ? `User context: ${accountContext}\n\nQuestion: ${message}`
    : message;

  const model = 'gemini-2.0-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;

  try {
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
      return { provider: 'gemini', name: 'Google Gemini', model, message: '', error: `HTTP ${response.status}`, durationMs: Date.now() - t0 };
    }

    const data = await response.json();
    return {
      provider: 'gemini',
      name: 'Google Gemini',
      model,
      message: data.candidates?.[0]?.content?.parts?.[0]?.text || 'No response generated.',
      durationMs: Date.now() - t0,
    };
  } catch (err) {
    return { provider: 'gemini', name: 'Google Gemini', model, message: '', error: String(err), durationMs: Date.now() - t0 };
  }
}

const API_KEYS: Record<string, string> = {
  anthropic: ANTHROPIC_API_KEY,
  openai: OPENAI_API_KEY,
  gemini: GEMINI_API_KEY,
  xai: XAI_API_KEY,
  openrouter: OPENROUTER_API_KEY,
};

interface ProviderEntry {
  key: string;
  name: string;
  call: (message: string, accountContext?: string) => Promise<ProviderResult>;
}

const allProviders: ProviderEntry[] = [
  { key: 'anthropic', name: 'Anthropic Claude', call: callAnthropic },
  { key: 'openai', name: 'OpenAI GPT', call: (msg, ctx) => callOpenAICompatible(OPENAI_API_KEY, 'https://api.openai.com/v1/chat/completions', 'gpt-4o-mini', 'openai', 'OpenAI GPT', msg, ctx) },
  { key: 'gemini', name: 'Google Gemini', call: callGemini },
  { key: 'xai', name: 'xAI Grok', call: (msg, ctx) => callOpenAICompatible(XAI_API_KEY, 'https://api.x.ai/v1/chat/completions', 'grok-3-mini', 'xai', 'xAI Grok', msg, ctx) },
  { key: 'openrouter', name: 'OpenRouter', call: (msg, ctx) => callOpenAICompatible(OPENROUTER_API_KEY, 'https://openrouter.ai/api/v1/chat/completions', 'mistralai/mistral-small-3.2-24b-instruct', 'openrouter', 'OpenRouter', msg, ctx) },
];

export async function GET() {
  const available = allProviders
    .filter(p => !!API_KEYS[p.key])
    .map(p => ({ id: p.key, name: p.name }));

  return NextResponse.json({ providers: available });
}

export async function POST(request: NextRequest) {
  try {
    const { message, accountContext } = await request.json();

    if (!message || typeof message !== 'string') {
      return NextResponse.json({ error: 'Message is required' }, { status: 400 });
    }

    const contextStr = accountContext ? JSON.stringify(accountContext) : undefined;

    const configured = allProviders.filter(p => !!API_KEYS[p.key]);

    const results = await Promise.all(
      configured.map(p => p.call(message, contextStr))
    );

    return NextResponse.json({ results });
  } catch (error) {
    console.error('AI chat error:', error);
    return NextResponse.json({ error: 'AI service unavailable' }, { status: 503 });
  }
}
