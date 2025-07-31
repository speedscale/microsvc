import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  images: {
    unoptimized: true,
  },
  // experimental: {
  //   instrumentationHook: true,
  // } as any,
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: `${process.env.BACKEND_API_URL || 'http://localhost:8080'}/api/:path*`,
      },
    ]
  },
};

export default nextConfig;
