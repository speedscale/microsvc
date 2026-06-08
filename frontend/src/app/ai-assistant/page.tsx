'use client';

import React, { useState, useRef, useEffect } from 'react';
import ProtectedRoute from '@/components/auth/ProtectedRoute';
import AuthenticatedLayout from '@/components/layout/AuthenticatedLayout';
import { TokenManager } from '@/lib/auth/token';

interface ChatMessage {
  role: 'user' | 'assistant';
  content: string;
  provider?: string;
  model?: string;
}

interface ProviderInfo {
  id: string;
  name: string;
}

const PROVIDER_COLORS: Record<string, string> = {
  anthropic: 'bg-orange-100 text-orange-800',
  openai: 'bg-green-100 text-green-800',
  gemini: 'bg-blue-100 text-blue-800',
  xai: 'bg-purple-100 text-purple-800',
  openrouter: 'bg-pink-100 text-pink-800',
};

const AIAssistantPage: React.FC = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [providers, setProviders] = useState<ProviderInfo[]>([]);
  const [selectedProvider, setSelectedProvider] = useState('anthropic');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  useEffect(() => {
    fetch('/api/ai/chat')
      .then(res => res.json())
      .then(data => {
        if (data.providers?.length > 0) {
          setProviders(data.providers);
          setSelectedProvider(data.providers[0].id);
        }
      })
      .catch(() => {});
  }, []);

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
        body: JSON.stringify({ message: trimmed, provider: selectedProvider }),
      });

      const data = await res.json();

      const assistantMessage: ChatMessage = {
        role: 'assistant',
        content: res.ok ? data.message : (data.error || 'Something went wrong. Please try again.'),
        provider: data.provider,
        model: data.model,
      };
      setMessages(prev => [...prev, assistantMessage]);
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
        <div className="max-w-3xl mx-auto py-6 px-4 sm:px-6 lg:px-8 flex flex-col" style={{ height: 'calc(100vh - 64px)' }}>
          <div className="mb-4">
            <h1 className="text-2xl font-bold text-gray-900">AI Banking Assistant</h1>
            <p className="text-sm text-gray-600">Ask questions about your accounts and transactions</p>
          </div>

          <div className="flex-1 overflow-y-auto bg-white shadow rounded-lg p-4 mb-4 space-y-4">
            {messages.length === 0 && (
              <div className="text-center text-gray-400 py-12">
                <p className="text-lg font-medium mb-2">No messages yet</p>
                <p className="text-sm">Try asking about your account balance or recent transactions.</p>
              </div>
            )}

            {messages.map((msg, i) => (
              <div
                key={i}
                className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
              >
                <div className={`max-w-[75%] ${msg.role === 'user' ? '' : 'space-y-1'}`}>
                  <div
                    className={`rounded-lg px-4 py-2 text-sm whitespace-pre-wrap ${
                      msg.role === 'user'
                        ? 'bg-blue-600 text-white'
                        : 'bg-gray-100 text-gray-900'
                    }`}
                  >
                    {msg.content}
                  </div>
                  {msg.role === 'assistant' && msg.provider && (
                    <div className="flex items-center gap-2 px-1">
                      <span className={`inline-block text-xs px-2 py-0.5 rounded-full font-medium ${PROVIDER_COLORS[msg.provider] || 'bg-gray-100 text-gray-600'}`}>
                        {msg.provider}
                      </span>
                      {msg.model && (
                        <span className="text-xs text-gray-400">{msg.model}</span>
                      )}
                    </div>
                  )}
                </div>
              </div>
            ))}

            {isLoading && (
              <div className="flex justify-start">
                <div className="bg-gray-100 rounded-lg px-4 py-2 text-sm text-gray-500">
                  Thinking...
                </div>
              </div>
            )}

            <div ref={messagesEndRef} />
          </div>

          <div className="flex gap-2 items-center">
            {providers.length > 1 && (
              <select
                value={selectedProvider}
                onChange={e => setSelectedProvider(e.target.value)}
                className="rounded-lg border border-gray-300 px-3 py-2 text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              >
                {providers.map(p => (
                  <option key={p.id} value={p.id}>{p.name}</option>
                ))}
              </select>
            )}
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
