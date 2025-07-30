import { NextRequest, NextResponse } from 'next/server';
import { logApiRequest } from './lib/logger';

export function middleware(request: NextRequest) {
  // Only log API requests
  if (request.nextUrl.pathname.startsWith('/api/')) {
    const method = request.method;
    const url = request.nextUrl.pathname + request.nextUrl.search;
    const userAgent = request.headers.get('user-agent') || undefined;
    const forwarded = request.headers.get('x-forwarded-for') || undefined;

    // Use winston logger instead of console.log
    logApiRequest(method, url, userAgent, forwarded);
  }

  return NextResponse.next();
}

export const config = {
  matcher: [
    // Match all API routes
    '/api/:path*',
  ],
};