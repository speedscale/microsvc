const bcrypt = require('bcryptjs');

const password = 'SimUser123!';
const saltRounds = 10;

bcrypt.hash(password, saltRounds, (err, hash) => {
    if (err) {
        console.error('Error generating hash:', err);
    } else {
        console.log('BCrypt hash for "SimUser123!":', hash);
    }
});