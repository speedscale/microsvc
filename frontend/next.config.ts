import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  images: {
    unoptimized: true,
  },
  experimental: {
    instrumentationHook: true,
  } as any,
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${process.env.BACKEND_API_URL || 'http://api-gateway:80'}/api/:path*`,
      },
    ]
  },
};

export default nextConfig;
