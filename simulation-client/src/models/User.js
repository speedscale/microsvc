const config = require('../config');
const { getProfileForUserNumber, getRandomProfile } = require('./personas');

class User {
  constructor(data = {}) {
    this.id = data.id || null;
    this.username = data.username || null;
    this.email = data.email || null;
    this.firstName = data.firstName || null;
    this.lastName = data.lastName || null;
    this.displayName = data.displayName || this.username;
    this.locale = data.locale || 'en-US';
    this.language = data.language || 'English';
    this.password = data.password || null;
    this.roles = data.roles || [];
    this.token = data.token || null;
    this.accounts = data.accounts || [];
    this.isPreExisting = data.isPreExisting || false;
    this.sessionStartTime = data.sessionStartTime || null;
    this.lastActionTime = data.lastActionTime || null;
  }

  static generateSimulationUser(userNumber) {
    const profile = getProfileForUserNumber(userNumber);
    
    return new User({
      ...profile,
      password: config.userPool.password,
      isPreExisting: true
    });
  }

  static generateNewUser() {
    const profile = getRandomProfile();
    
    return new User({
      ...profile,
      password: config.userPool.password,
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
      displayName: this.displayName,
      locale: this.locale,
      isPreExisting: this.isPreExisting,
      isAuthenticated: this.isAuthenticated(),
      sessionDuration: this.getSessionDuration()
    };
  }
}

module.exports = User;
