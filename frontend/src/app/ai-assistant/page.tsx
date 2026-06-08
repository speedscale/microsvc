'use client';

import React, { useState, useRef, useEffect } from 'react';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import AuthenticatedLayout from '@/components/layout/AuthenticatedLayout';
import { TokenManager } from '@/lib/auth/token';

interface ProviderResult {
  provider: string;
  name: string;
  model: string;
  message: string;
  error?: string;
  durationMs: number;
}

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  results?: ProviderResult[];
}

const PROVIDER_COLORS: Record<string, { bg: string; border: string; badge: string }> = {
  anthropic: { bg: 'bg-orange-50', border: 'border-orange-200', badge: 'bg-orange-100 text-orange-800' },
  openai: { bg: 'bg-green-50', border: 'border-green-200', badge: 'bg-green-100 text-green-800' },
  gemini: { bg: 'bg-blue-50', border: 'border-blue-200', badge: 'bg-blue-100 text-blue-800' },
  xai: { bg: 'bg-purple-50', border: 'border-purple-200', badge: 'bg-purple-100 text-purple-800' },
  openrouter: { bg: 'bg-pink-50', border: 'border-pink-200', badge: 'bg-pink-100 text-pink-800' },
};

const AIAssistantPage: React.FC = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const sendMessage = async () => {
    const trimmed = input.trim();
    if (!trimmed || isLoading) return;

    const userMessage: ChatMessage = { role: 'user', content: trimmed };
    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const token = TokenManager.getToken();
      const res = await fetch('/api/ai/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(token && { Authorization: `Bearer ${token}` }),
        },
        body: JSON.stringify({ message: trimmed }),
      });

      const data = await res.json();

      if (data.results) {
        const assistantMessage: ChatMessage = {
          role: 'assistant',
          content: '',
          results: data.results,
        };
        setMessages(prev => [...prev, assistantMessage]);
      } else {
        setMessages(prev => [
          ...prev,
          { role: 'assistant', content: data.error || 'Something went wrong.' },
        ]);
      }
    } catch {
      setMessages(prev => [
        ...prev,
        { role: 'assistant', content: 'Unable to reach the AI service. Please try again later.' },
      ]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <ProtectedRoute requireAuth={true}>
      <AuthenticatedLayout>
        <div className="max-w-5xl mx-auto py-6 px-4 sm:px-6 lg:px-8 flex flex-col" style={{ height: 'calc(100vh - 64px)' }}>
          <div className="mb-4">
            <h1 className="text-2xl font-bold text-gray-900">AI Banking Assistant</h1>
            <p className="text-sm text-gray-600">Ask a question — all configured LLM providers respond simultaneously</p>
          </div>

          <div className="flex-1 overflow-y-auto bg-white shadow rounded-lg p-4 mb-4 space-y-4">
            {messages.length === 0 && (
              <div className="text-center text-gray-400 py-12">
                <p className="text-lg font-medium mb-2">No messages yet</p>
                <p className="text-sm">Try asking about your account balance or recent transactions.</p>
              </div>
            )}

            {messages.map((msg, i) => (
              <div key={i}>
                {msg.role === 'user' ? (
                  <div className="flex justify-end">
                    <div className="max-w-[75%] rounded-lg px-4 py-2 text-sm whitespace-pre-wrap bg-blue-600 text-white">
                      {msg.content}
                    </div>
                  </div>
                ) : msg.results ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3">
                    {msg.results.map((r, j) => {
                      const colors = PROVIDER_COLORS[r.provider] || { bg: 'bg-gray-50', border: 'border-gray-200', badge: 'bg-gray-100 text-gray-600' };
                      return (
                        <div key={j} className={`rounded-lg border ${colors.border} ${colors.bg} p-3 text-sm`}>
                          <div className="flex items-center justify-between mb-2">
                            <span className={`inline-block text-xs px-2 py-0.5 rounded-full font-medium ${colors.badge}`}>
                              {r.name}
                            </span>
                            <span className="text-xs text-gray-400">{r.durationMs}ms</span>
                          </div>
                          {r.error ? (
                            <div className="text-red-600 text-xs">
                              <span className="font-medium">Error:</span> {r.error}
                            </div>
                          ) : (
                            <div className="text-gray-900 whitespace-pre-wrap">{r.message}</div>
                          )}
                          <div className="mt-2 text-xs text-gray-400">{r.model}</div>
                        </div>
                      );
                    })}
                  </div>
                ) : (
                  <div className="flex justify-start">
                    <div className="max-w-[75%] rounded-lg px-4 py-2 text-sm whitespace-pre-wrap bg-gray-100 text-gray-900">
                      {msg.content}
                    </div>
                  </div>
                )}
              </div>
            ))}

            {isLoading && (
              <div className="flex justify-start">
                <div className="bg-gray-100 rounded-lg px-4 py-2 text-sm text-gray-500">
                  Querying all providers...
                </div>
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          <div className="flex gap-2">
            <input
              type="text"
              value={input}
              onChange={e => setInput(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Ask a question..."
              disabled={isLoading}
              className="flex-1 rounded-lg border border-gray-300 px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent disabled:bg-gray-50"
            />
            <button
              onClick={sendMessage}
              disabled={isLoading || !input.trim()}
              className="bg-blue-600 hover:bg-blue-700 disabled:bg-blue-300 text-white px-6 py-2 rounded-lg text-sm font-medium transition-colors"
            >
              Send
            </button>
          </div>
        </div>
      </AuthenticatedLayout>
    </ProtectedRoute>
  );
};

export default AIAssistantPage;
