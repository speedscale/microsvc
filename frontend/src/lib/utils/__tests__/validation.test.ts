import {
  loginSchema,
  registerSchema,
  createAccountSchema,
  createTransactionSchema,
  updateProfileSchema,
  changePasswordSchema,
  searchSchema,
  contactSchema,
  preferencesSchema,
} from '../validation';

describe('Validation Schemas', () => {
  describe('loginSchema', () => {
    it('validates valid login data', () => {
      const validData = {
        usernameOrEmail: 'testuser',
        password: 'password123',
      };

      const result = loginSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('validates email login', () => {
      const validData = {
        usernameOrEmail: 'test@example.com',
        password: 'password123',
      };

      const result = loginSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('rejects empty username/email', () => {
      const invalidData = {
        usernameOrEmail: '',
        password: 'password123',
      };

      const result = loginSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Username or email is required');
      }
    });

    it('rejects short password', () => {
      const invalidData = {
        usernameOrEmail: 'testuser',
        password: '123',
      };

      const result = loginSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Password must be at least 8 characters');
      }
    });
  });

  describe('registerSchema', () => {
    it('validates valid registration data', () => {
      const validData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'password123',
        generateDemoData: false,
      };

      const result = registerSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('rejects short username', () => {
      const invalidData = {
        username: 'ab',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'password123',
        generateDemoData: false,
      };

      const result = registerSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Username must be at least 3 characters');
      }
    });

    it('rejects invalid username characters', () => {
      const invalidData = {
        username: 'test-user',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'password123',
        generateDemoData: false,
      };

      const result = registerSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Username can only contain letters, numbers, and underscores');
      }
    });

    it('rejects invalid email', () => {
      const invalidData = {
        username: 'testuser',
        email: 'invalid-email',
        password: 'password123',
        confirmPassword: 'password123',
        generateDemoData: false,
      };

      const result = registerSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Please enter a valid email address');
      }
    });

    it('rejects mismatched passwords', () => {
      const invalidData = {
        username: 'testuser',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'differentpassword',
        generateDemoData: false,
      };

      const result = registerSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Passwords do not match');
      }
    });
  });

  describe('createAccountSchema', () => {
    it('validates valid account data', () => {
      const validData = {
        accountType: 'CHECKING' as const,
        initialBalance: 1000,
        currency: 'USD',
      };

      const result = createAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('uses default currency when not provided', () => {
      const validData = {
        accountType: 'SAVINGS' as const,
        initialBalance: 500,
      };

      const result = createAccountSchema.safeParse(validData);
      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.data.currency).toBe('USD');
      }
    });

    it('rejects invalid account type', () => {
      const invalidData = {
        accountType: 'INVALID' as unknown,
        initialBalance: 1000,
      };

      const result = createAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });

    it('rejects negative balance', () => {
      const invalidData = {
        accountType: 'CHECKING' as const,
        initialBalance: -100,
      };

      const result = createAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Initial balance cannot be negative');
      }
    });

    it('rejects invalid currency format', () => {
      const invalidData = {
        accountType: 'CHECKING' as const,
        currency: 'usd',
      };

      const result = createAccountSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Currency code must be uppercase letters');
      }
    });
  });

  describe('createTransactionSchema', () => {
    it('validates valid deposit transaction', () => {
      const validData = {
        accountId: 1,
        type: 'DEPOSIT' as const,
        amount: 100,
        currency: 'USD',
        description: 'Test deposit',
      };

      const result = createTransactionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('validates valid transfer transaction', () => {
      const validData = {
        accountId: 1,
        toAccountId: 2,
        type: 'TRANSFER' as const,
        amount: 50,
        currency: 'EUR',
        description: 'Test transfer',
      };

      const result = createTransactionSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('rejects transfer without destination account', () => {
      const invalidData = {
        accountId: 1,
        type: 'TRANSFER' as const,
        amount: 50,
        description: 'Test transfer',
      };

      const result = createTransactionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Destination account is required for transfers');
      }
    });

    it('rejects zero amount', () => {
      const invalidData = {
        accountId: 1,
        type: 'DEPOSIT' as const,
        amount: 0,
        description: 'Test deposit',
      };

      const result = createTransactionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Amount must be greater than 0');
      }
    });

    it('rejects negative amount', () => {
      const invalidData = {
        accountId: 1,
        type: 'DEPOSIT' as const,
        amount: -10,
        description: 'Test deposit',
      };

      const result = createTransactionSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Amount must be greater than 0');
      }
    });
  });

  describe('updateProfileSchema', () => {
    it('validates valid profile data', () => {
      const validData = {
        firstName: 'John',
        lastName: 'Doe',
        email: 'john@example.com',
        phone: '+1234567890',
      };

      const result = updateProfileSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('rejects invalid first name characters', () => {
      const invalidData = {
        firstName: 'John123',
        lastName: 'Doe',
        email: 'john@example.com',
      };

      const result = updateProfileSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('First name can only contain letters, spaces, hyphens, and apostrophes');
      }
    });
  });

  describe('changePasswordSchema', () => {
      it('validates valid password change data', () => {
    const validData = {
      currentPassword: 'oldpassword123',
      newPassword: 'newpassword123',
      confirmPassword: 'newpassword123',
    };

    const result = changePasswordSchema.safeParse(validData);
    expect(result.success).toBe(true);
  });

  it('rejects mismatched new passwords', () => {
    const invalidData = {
      currentPassword: 'oldpassword123',
      newPassword: 'newpassword123',
      confirmPassword: 'differentpassword',
    };

    const result = changePasswordSchema.safeParse(invalidData);
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0].message).toBe('Passwords do not match');
    }
  });
  });

  describe('searchSchema', () => {
    it('validates valid search data', () => {
      const validData = {
        query: 'test search',
        type: 'accounts' as const,
        dateFrom: '2023-01-01',
        dateTo: '2023-12-31',
      };

      const result = searchSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('rejects empty query', () => {
      const invalidData = {
        query: '',
        type: 'accounts' as const,
      };

      const result = searchSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Search query is required');
      }
    });
  });

  describe('contactSchema', () => {
    it('validates valid contact data', () => {
      const validData = {
        name: 'John Doe',
        email: 'john@example.com',
        subject: 'Test Subject',
        message: 'This is a test message',
      };

      const result = contactSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('rejects invalid email', () => {
      const invalidData = {
        name: 'John Doe',
        email: 'invalid-email',
        subject: 'Test Subject',
        message: 'This is a test message',
      };

      const result = contactSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toBe('Please enter a valid email address');
      }
    });
  });

  describe('preferencesSchema', () => {
    it('validates valid preferences data', () => {
      const validData = {
        emailNotifications: true,
        smsNotifications: false,
        language: 'en' as const,
        timezone: 'UTC',
        currency: 'USD',
      };

      const result = preferencesSchema.safeParse(validData);
      expect(result.success).toBe(true);
    });

    it('rejects invalid language', () => {
      const invalidData = {
        emailNotifications: true,
        language: 'invalid' as unknown,
      };

      const result = preferencesSchema.safeParse(invalidData);
      expect(result.success).toBe(false);
    });
  });
}); 