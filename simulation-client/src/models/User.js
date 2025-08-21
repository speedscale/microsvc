class User {
  constructor(data = {}) {
    this.id = data.id || null;
    this.username = data.username || null;
    this.email = data.email || null;
    this.password = data.password || null;
    this.roles = data.roles || [];
    this.token = data.token || null;
    this.accounts = data.accounts || [];
    this.isPreExisting = data.isPreExisting || false;
    this.sessionStartTime = data.sessionStartTime || null;
    this.lastActionTime = data.lastActionTime || null;
  }

  static generateSimulationUser(userNumber) {
    const username = `sim_user_${userNumber.toString().padStart(3, '0')}`;
    const email = `${username}@simulation.local`;
    
    return new User({
      username,
      email,
      password: 'NewUser123!',
      isPreExisting: true
    });
  }

  static generateNewUser() {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000);
    const username = `new_user_${timestamp}_${random}`;
    const email = `${username}@example.com`;
    
    return new User({
      username,
      email,
      password: 'NewUser123!',
      isPreExisting: false
    });
  }

  setAuthToken(token) {
    this.token = token;
  }

  startSession() {
    this.sessionStartTime = new Date();
    this.lastActionTime = new Date();
  }

  updateLastAction() {
    this.lastActionTime = new Date();
  }

  getSessionDuration() {
    if (!this.sessionStartTime) return 0;
    return Date.now() - this.sessionStartTime.getTime();
  }

  isAuthenticated() {
    return !!this.token;
  }

  toLogData() {
    return {
      id: this.id,
      username: this.username,
      isPreExisting: this.isPreExisting,
      isAuthenticated: this.isAuthenticated(),
      sessionDuration: this.getSessionDuration()
    };
  }
}

module.exports = User;