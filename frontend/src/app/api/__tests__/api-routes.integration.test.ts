import { createMocks } from 'node-mocks-http';
import { NextApiRequest, NextApiResponse } from 'next';
import { GET, POST } from '../accounts/route';

// This is an example of how to test API routes
// Note: This requires additional setup and a running database

describe('API Routes Integration Tests', () => {
  describe('GET /api/accounts', () => {
    it('should return accounts list', async () => {
      const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
        method: 'GET',
        query: {},
      });

      await GET(req, res);

      expect(res._getStatusCode()).toBe(200);
      const data = JSON.parse(res._getData());
      expect(Array.isArray(data)).toBe(true);
    });
  });

  describe('POST /api/accounts', () => {
    it('should create a new account', async () => {
      const { req, res } = createMocks<NextApiRequest, NextApiResponse>({
        method: 'POST',
        body: {
          accountType: 'CHECKING',
          initialBalance: 1000,
          currency: 'USD',
        },
      });

      await POST(req, res);

      expect(res._getStatusCode()).toBe(201);
      const data = JSON.parse(res._getData());
      expect(data).toHaveProperty('id');
      expect(data.accountType).toBe('CHECKING');
    });
  });
}); 