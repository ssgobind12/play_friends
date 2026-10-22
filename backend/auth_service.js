/**
 * Play Friends — Authentication & Authorization Core Service
 *
 * Implements:
 * - Scrypt password hashing with unique random salts & constant-time verification
 * - Secure OTP lifecycle (SHA-256 hashed verifier, 5-min expiry, max 3 attempts, 60s rate limit)
 * - Single-use purpose-bound verification tokens
 * - Session token issuance (30 days), validation, and revocation
 * - Server-side role authorization (strictly 'user' for public registration)
 * - Brevo transactional email delivery with strict provider response awaiting
 * - Secure bootstrap provisioning for administrator (from env var, never hardcoded)
 */

const crypto = require('crypto');
const Storage = require('./storage');

const BREVO_API_KEY = process.env.BREVO_API_KEY || '';
const BREVO_SENDER_EMAIL = process.env.BREVO_SENDER_EMAIL || 'noreply@ssgobind.space';
const BREVO_SENDER_NAME = process.env.BREVO_SENDER_NAME || 'Play Friends';
const BREVO_REPLY_TO = process.env.BREVO_REPLY_TO || 'playgamefriendes@gmail.com';

// In-memory rate limiting map for OTP requests: key -> timestamp
const lastOtpRequests = new Map();

class AuthService {
  // ---------------------------------------------------------------------------
  // PASSWORD HASHING (SCRYPT WITH UNIQUE 16-BYTE SALTS)
  // ---------------------------------------------------------------------------

  static async hashPassword(password) {
    if (!password || typeof password !== 'string' || password.length < 6) {
      throw new Error('Password must be at least 6 characters long');
    }
    return new Promise((resolve, reject) => {
      const salt = crypto.randomBytes(16).toString('hex');
      const N = 16384, r = 8, p = 1, keyLen = 64;
      crypto.scrypt(password, salt, keyLen, { N, r, p }, (err, derivedKey) => {
        if (err) return reject(err);
        resolve(`scrypt$${N}$${r}$${p}$${salt}$${derivedKey.toString('hex')}`);
      });
    });
  }

  static async verifyPassword(password, storedHash) {
    if (!password || !storedHash || typeof storedHash !== 'string') return false;

    // Modern scrypt format: scrypt$N$r$p$salt$hash
    if (storedHash.startsWith('scrypt$')) {
      const parts = storedHash.split('$');
      if (parts.length !== 6) return false;
      const N = parseInt(parts[1], 10);
      const r = parseInt(parts[2], 10);
      const p = parseInt(parts[3], 10);
      const salt = parts[4];
      const expectedHashBuf = Buffer.from(parts[5], 'hex');

      return new Promise((resolve) => {
        crypto.scrypt(password, salt, expectedHashBuf.length, { N, r, p }, (err, derivedKey) => {
          if (err) return resolve(false);
          try {
            const match = crypto.timingSafeEqual(derivedKey, expectedHashBuf);
            resolve(match);
          } catch {
            resolve(false);
          }
        });
      });
    }

    // PBKDF2 format: pbkdf2$iterations$salt$hash
    if (storedHash.startsWith('pbkdf2$')) {
      const parts = storedHash.split('$');
      if (parts.length === 4) {
        const iterations = parseInt(parts[1], 10);
        const salt = parts[2];
        const expectedHash = parts[3];
        const derivedKey = crypto.pbkdf2Sync(password, salt, iterations, 32, 'sha256').toString('hex');
        try {
          return crypto.timingSafeEqual(Buffer.from(derivedKey, 'hex'), Buffer.from(expectedHash, 'hex'));
        } catch {
          return false;
        }
      }
    }

    // Legacy SHA-256 fallback migration
    const legacySalt = 'pf_salt_2026_secure';
    const legacyHash = crypto.createHash('sha256').update(`${legacySalt}:${password}`).digest('hex');
    try {
      if (crypto.timingSafeEqual(Buffer.from(legacyHash, 'hex'), Buffer.from(storedHash, 'hex'))) {
        return true;
      }
    } catch {
      // lengths don't match
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // OTP LIFECYCLE & BREVO EMAIL DELIVERY
  // ---------------------------------------------------------------------------

  static _hashOtp(code) {
    return crypto.createHash('sha256').update(code.trim()).digest('hex');
  }

  static async requestOtp({ email, purpose, name }) {
    const cleanEmail = (email || '').toLowerCase().trim();
    if (!cleanEmail || !cleanEmail.includes('@') || !cleanEmail.includes('.')) {
      return { success: false, statusCode: 400, error: 'Please enter a valid email address.' };
    }

    if (purpose !== 'registration' && purpose !== 'password_reset') {
      return { success: false, statusCode: 400, error: 'Invalid OTP purpose.' };
    }

    // If password reset, ensure account exists
    if (purpose === 'password_reset') {
      const existingUser = await Storage.getUserByEmail(cleanEmail);
      if (!existingUser) {
        return { success: false, statusCode: 404, error: 'No account found with this email address. Please register.' };
      }
    }

    // Rate limiting: 60-second cooldown per email/purpose
    const rateKey = `${cleanEmail}:${purpose}`;
    const lastRequest = lastOtpRequests.get(rateKey);
    const now = Date.now();
    if (lastRequest && (now - lastRequest) < 60000) {
      const remainingSeconds = Math.ceil((60000 - (now - lastRequest)) / 1000);
      return {
        success: false,
        statusCode: 429,
        error: `Please wait ${remainingSeconds} seconds before requesting another code.`
      };
    }
    lastOtpRequests.set(rateKey, now);

    // Generate cryptographically secure 6-digit OTP
    const rawOtp = crypto.randomInt(100000, 1000000).toString();
    const hashedOtp = this._hashOtp(rawOtp);
    const expiresAt = now + 5 * 60 * 1000; // 5-minute expiry

    // Save hashed OTP in database
    await Storage.saveOtp({
      email: cleanEmail,
      purpose,
      hashedOtp,
      createdAt: now,
      expiresAt,
      failedAttempts: 0,
      isUsed: false
    });

    // Dispatch via Brevo
    const emailResult = await this._sendBrevoEmail({
      toEmail: cleanEmail,
      toName: name || 'Player',
      otpCode: rawOtp,
      purpose
    });

    if (!emailResult.success) {
      return {
        success: false,
        statusCode: 502,
        error: emailResult.error || 'Failed to dispatch verification email. Please try again later.'
      };
    }

    return {
      success: true,
      statusCode: 200,
      message: `A 6-digit verification code has been dispatched to ${cleanEmail}.`,
      expiresInSeconds: 300
    };
  }

  static async verifyOtp({ email, otp, purpose }) {
    const cleanEmail = (email || '').toLowerCase().trim();
    const cleanOtp = (otp || '').trim();

    if (!cleanEmail || !cleanOtp || cleanOtp.length !== 6) {
      return { success: false, statusCode: 400, error: 'Valid email and 6-digit code are required.' };
    }

    const record = await Storage.getActiveOtp(cleanEmail, purpose);
    if (!record || record.isUsed) {
      return { success: false, statusCode: 400, error: 'No active verification code found. Please request a new code.' };
    }

    const now = Date.now();
    if (now > record.expiresAt) {
      await Storage.updateOtp(cleanEmail, purpose, { isUsed: true, failedAttempts: record.failedAttempts });
      return { success: false, statusCode: 400, error: 'Verification code has expired. Please request a new code.' };
    }

    if (record.failedAttempts >= 3) {
      await Storage.updateOtp(cleanEmail, purpose, { isUsed: true, failedAttempts: record.failedAttempts });
      return { success: false, statusCode: 400, error: 'Maximum verification attempts exceeded. Code has been invalidated.' };
    }

    // Verify OTP hash
    const candidateHash = this._hashOtp(cleanOtp);
    const isMatch = candidateHash === record.hashedOtp;

    if (!isMatch) {
      const newAttempts = record.failedAttempts + 1;
      const isMaxed = newAttempts >= 3;
      await Storage.updateOtp(cleanEmail, purpose, {
        isUsed: isMaxed,
        failedAttempts: newAttempts
      });

      if (isMaxed) {
        return { success: false, statusCode: 400, error: 'Maximum verification attempts exceeded. Code has been invalidated.' };
      }
      const remaining = 3 - newAttempts;
      return { success: false, statusCode: 400, error: `Incorrect verification code. ${remaining} attempt(s) remaining.` };
    }

    // Valid: Mark OTP used atomically
    await Storage.updateOtp(cleanEmail, purpose, { isUsed: true, failedAttempts: record.failedAttempts });

    // Issue single-use 10-minute verification token
    const token = `pf_vtok_${crypto.randomBytes(24).toString('hex')}_${Date.now()}`;
    await Storage.saveVerificationToken({
      token,
      email: cleanEmail,
      purpose,
      expiresAt: now + 10 * 60 * 1000
    });

    return {
      success: true,
      statusCode: 200,
      message: 'OTP verified successfully.',
      verificationToken: token
    };
  }

  static async _sendBrevoEmail({ toEmail, toName, otpCode, purpose }) {
    if (!BREVO_API_KEY) {
      // In test / offline development mode, do not crash; simulate delivery
      if (process.env.NODE_ENV === 'test' || process.env.ALLOW_SIMULATED_BREVO === 'true') {
        return { success: true, simulated: true };
      }
      return { success: false, error: 'Brevo email provider is not configured on the server.' };
    }

    const isRegistration = purpose === 'registration';
    const subject = isRegistration
      ? 'Your Play Friends verification code is ' + otpCode
      : 'Your Play Friends password reset code is ' + otpCode;

    const bodyPayload = {
      sender: { name: BREVO_SENDER_NAME, email: BREVO_SENDER_EMAIL },
      to: [{ email: toEmail, name: toName }],
      replyTo: { email: BREVO_REPLY_TO },
      subject,
      htmlContent: `
        <div style="font-family: Arial, sans-serif; background: #0D1117; color: #FFFFFF; padding: 30px; border-radius: 12px; max-width: 500px;">
          <h2 style="color: #A78BFA; margin-top: 0;">Play Friends Verification</h2>
          <p>Hello ${toName},</p>
          <p>${isRegistration ? 'Thank you for registering on Play Friends! Your 6-digit email verification code is:' : 'You requested a password reset for Play Friends. Your 6-digit reset code is:'}</p>
          <div style="background: #1F2937; padding: 18px; border-radius: 8px; text-align: center; margin: 25px 0;">
            <span style="font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #34D399;">${otpCode}</span>
          </div>
          <p style="color: #9CA3AF; font-size: 13px;">This code will expire in 5 minutes. If you did not request this code, please ignore this email.</p>
        </div>
      `,
      textContent: `Hello ${toName},\n\nYour Play Friends verification code is: ${otpCode}\n\nThis code expires in 5 minutes.`
    };

    try {
      const response = await fetch('https://api.brevo.com/v3/smtp/email', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'api-key': BREVO_API_KEY,
          'Accept': 'application/json'
        },
        body: JSON.stringify(bodyPayload)
      });

      if (response.ok) {
        return { success: true };
      }
      const errBody = await response.text();
      return { success: false, error: `Brevo rejected email (${response.status}): ${errBody}` };
    } catch (err) {
      return { success: false, error: `Network error connecting to Brevo: ${err.message}` };
    }
  }

  // ---------------------------------------------------------------------------
  // REGISTRATION & LOGIN
  // ---------------------------------------------------------------------------

  static async registerUser({
    name,
    tag,
    email,
    password,
    phoneNumber,
    countryCode,
    countryFlag,
    avatarColor,
    verificationToken
  }) {
    const cleanEmail = (email || '').toLowerCase().trim();
    const cleanPhone = (phoneNumber || '').replace(/\D/g, '');

    if (!cleanEmail || !password || password.length < 6) {
      return { success: false, statusCode: 400, error: 'Valid email and password (min 6 characters) are required.' };
    }

    if (!cleanPhone || cleanPhone.length < 7 || cleanPhone.length > 15) {
      return { success: false, statusCode: 400, error: 'Valid phone number (7-15 digits) is required.' };
    }

    if (!verificationToken) {
      return { success: false, statusCode: 401, error: 'Registration requires a verified email OTP token.' };
    }

    // Verify and consume token atomically
    const tokenValid = await Storage.consumeVerificationToken(verificationToken, 'registration', cleanEmail);
    if (!tokenValid) {
      return { success: false, statusCode: 401, error: 'Invalid or expired registration verification token.' };
    }

    // Hash password using scrypt
    const passwordHash = await this.hashPassword(password);
    const userId = `01${crypto.randomInt(100000, 999999)}`;

    const newUser = {
      id: userId,
      name: (name || 'Player').trim(),
      tag: (tag || `@player_${userId}`).trim(),
      email: cleanEmail,
      phoneNumber: cleanPhone,
      countryCode: countryCode || '+91',
      countryFlag: countryFlag || '🇮🇳',
      avatarColor: typeof avatarColor === 'number' ? avatarColor : 0xFF7C3AED,
      avatarInitial: ((name || 'P').trim()[0] || 'P').toUpperCase(),
      role: 'user', // STRICT: Public registration can NEVER assign admin role
      level: 1,
      coins: 500,
      trophies: 0,
      winRate: 0.0,
      totalMatches: 0,
      totalWins: 0,
      xp: 0,
      unlockedGameIds: ['tic_tac_toe'],
      passwordHash,
      createdAt: new Date().toISOString()
    };

    try {
      await Storage.createUserAtomic(newUser);
    } catch (err) {
      if (err.name === 'ConditionalCheckFailedException' || err.message.includes('ConditionalCheckFailed')) {
        return { success: false, statusCode: 409, error: 'An account with this email or phone number is already registered.' };
      }
      return { success: false, statusCode: 500, error: 'Database error during registration.' };
    }

    // Generate session
    const session = await this._createSession(newUser);
    const publicUser = { ...newUser };
    delete publicUser.passwordHash;

    return {
      success: true,
      statusCode: 201,
      user: publicUser,
      sessionToken: session.token
    };
  }

  static async loginUser({ identifier, password }) {
    const cleanId = (identifier || '').toLowerCase().trim();
    const cleanPhone = cleanId.replace(/\D/g, '');

    if (!cleanId || !password) {
      return { success: false, statusCode: 400, error: 'Identifier and password are required.' };
    }

    let user = await Storage.getUserByEmail(cleanId);
    if (!user && cleanPhone) {
      user = await Storage.getUserByPhone(cleanPhone);
    }

    if (!user) {
      return { success: false, statusCode: 401, error: 'Account not found. Please check your credentials or register.' };
    }

    const isMatch = await this.verifyPassword(password, user.passwordHash);
    if (!isMatch) {
      return { success: false, statusCode: 401, error: 'Incorrect password. Please try again.' };
    }

    // If legacy hash was matched, transparently upgrade to scrypt
    if (!user.passwordHash.startsWith('scrypt$')) {
      const newScrypt = await this.hashPassword(password);
      await Storage.updatePasswordHash(user.email, newScrypt);
    }

    const session = await this._createSession(user);
    const publicUser = { ...user };
    delete publicUser.passwordHash;

    return {
      success: true,
      statusCode: 200,
      user: publicUser,
      sessionToken: session.token
    };
  }

  // ---------------------------------------------------------------------------
  // SESSIONS
  // ---------------------------------------------------------------------------

  static async _createSession(user) {
    const token = `pf_sess_${Date.now()}_${crypto.randomBytes(32).toString('hex')}`;
    const expiresAt = Date.now() + 30 * 24 * 60 * 60 * 1000; // 30 days

    const sessionRecord = {
      token,
      userId: user.id,
      email: user.email,
      role: user.role || 'user',
      createdAt: Date.now(),
      expiresAt
    };

    await Storage.saveSession(sessionRecord);
    return sessionRecord;
  }

  static async validateSession(sessionToken) {
    if (!sessionToken || typeof sessionToken !== 'string') {
      return { success: false, statusCode: 401, error: 'Missing session token.' };
    }

    const session = await Storage.getSession(sessionToken.trim());
    if (!session) {
      return { success: false, statusCode: 401, error: 'Session expired or invalid. Please sign in again.' };
    }

    const user = await Storage.getUserByEmail(session.email);
    if (!user) {
      await Storage.deleteSession(sessionToken);
      return { success: false, statusCode: 401, error: 'User account no longer exists.' };
    }

    const publicUser = { ...user };
    delete publicUser.passwordHash;
    publicUser.sessionToken = sessionToken;

    return {
      success: true,
      statusCode: 200,
      user: publicUser,
      session: {
        userId: session.userId,
        role: session.role,
        expiresAt: session.expiresAt
      }
    };
  }

  static async logoutUser(sessionToken) {
    if (sessionToken) {
      await Storage.deleteSession(sessionToken.trim());
    }
    return { success: true, statusCode: 200, message: 'Logged out successfully.' };
  }

  // ---------------------------------------------------------------------------
  // PASSWORD RESET
  // ---------------------------------------------------------------------------

  static async resetPassword({ email, newPassword, verificationToken }) {
    const cleanEmail = (email || '').toLowerCase().trim();
    if (!cleanEmail || !newPassword || newPassword.length < 6) {
      return { success: false, statusCode: 400, error: 'Email and valid new password (min 6 characters) are required.' };
    }

    if (!verificationToken) {
      return { success: false, statusCode: 401, error: 'Password reset requires a verified OTP token.' };
    }

    const tokenValid = await Storage.consumeVerificationToken(verificationToken, 'password_reset', cleanEmail);
    if (!tokenValid) {
      return { success: false, statusCode: 401, error: 'Invalid or expired password reset verification token.' };
    }

    const user = await Storage.getUserByEmail(cleanEmail);
    if (!user) {
      return { success: false, statusCode: 404, error: 'Account not found.' };
    }

    const newHash = await this.hashPassword(newPassword);
    await Storage.updatePasswordHash(cleanEmail, newHash);

    // Invalidate all existing sessions for security
    await Storage.revokeAllUserSessions(cleanEmail);

    return {
      success: true,
      statusCode: 200,
      message: 'Password reset successfully. Please log in with your new password.'
    };
  }

  // ---------------------------------------------------------------------------
  // PROTECTED USER & SONG ACTIONS (OWNERSHIP ENFORCED)
  // ---------------------------------------------------------------------------

  static async checkUserExists({ email, phoneNumber }) {
    const cleanEmail = (email || '').toLowerCase().trim();
    const cleanPhone = (phoneNumber || '').replace(/\D/g, '');

    if (!cleanEmail && !cleanPhone) {
      return { success: false, statusCode: 400, error: 'Email or phone number is required.' };
    }

    if (cleanEmail) {
      const user = await Storage.getUserByEmail(cleanEmail);
      if (user) {
        return { success: true, statusCode: 200, exists: true, field: 'email', message: 'This email is already registered.' };
      }
    }

    if (cleanPhone) {
      const user = await Storage.getUserByPhone(cleanPhone);
      if (user) {
        return { success: true, statusCode: 200, exists: true, field: 'mobile', message: 'This mobile number is already registered.' };
      }
    }

    return { success: true, statusCode: 200, exists: false };
  }

  static async updateProfilePhoto({ sessionToken, profilePhoto, targetEmail }) {
    const authRes = await this.validateSession(sessionToken);
    if (!authRes.success) {
      return { success: false, statusCode: 401, error: 'Unauthorized: Valid session required.' };
    }

    const session = authRes.session;
    const emailToUpdate = (targetEmail || authRes.user.email).toLowerCase().trim();

    // Cross-user modification protection: regular user can only modify their own profile photo
    if (session.role !== 'admin' && emailToUpdate !== authRes.user.email) {
      return { success: false, statusCode: 403, error: 'Forbidden: You cannot modify another user\'s profile photo.' };
    }

    await Storage.updateProfilePhoto(emailToUpdate, profilePhoto);
    return { success: true, statusCode: 200, message: 'Profile photo updated.', profilePhoto };
  }

  static async uploadSong({ sessionToken, song }) {
    const authRes = await this.validateSession(sessionToken);
    if (!authRes.success) {
      return { success: false, statusCode: 401, error: 'Unauthorized: Valid session required.' };
    }

    if (!song || !song.id || !song.title) {
      return { success: false, statusCode: 400, error: 'Song id and title are required.' };
    }

    const user = authRes.user;
    // Bind song ownership strictly to the authenticated user
    const boundSong = {
      ...song,
      userId: user.id,
      uploadedAt: new Date().toISOString()
    };

    await Storage.saveSong(boundSong);
    return { success: true, statusCode: 201, message: 'Song uploaded successfully.', song: boundSong };
  }

  static async deleteSong({ sessionToken, songId }) {
    const authRes = await this.validateSession(sessionToken);
    if (!authRes.success) {
      return { success: false, statusCode: 401, error: 'Unauthorized: Valid session required.' };
    }

    const song = await Storage.getSong(songId);
    if (!song) {
      return { success: false, statusCode: 404, error: 'Song not found.' };
    }

    // Cross-user access protection
    if (authRes.session.role !== 'admin' && song.userId !== authRes.user.id) {
      return { success: false, statusCode: 403, error: 'Forbidden: You cannot delete a song you do not own.' };
    }

    await Storage.deleteSong(songId);
    return { success: true, statusCode: 200, message: 'Song deleted successfully.' };
  }

  static async getUserSongs({ userId, sessionToken }) {
    if (!userId) {
      return { success: false, statusCode: 400, error: 'User ID is required.' };
    }
    const songs = await Storage.getSongsByUserId(userId);
    return { success: true, statusCode: 200, songs };
  }

  // ---------------------------------------------------------------------------
  // SECURE ADMINISTRATOR PROVISIONING (NEVER HARDCODES PASSWORDS)
  // ---------------------------------------------------------------------------

  static async provisionAdminIfConfigured() {
    const adminEmail = process.env.ADMIN_EMAIL || 'ssgobind12@gmail.com';
    const adminAlt = 'ssgobind12@gamil.com';
    const adminPassword = process.env.ADMIN_INITIAL_PASSWORD;
    const adminPasswordHash = process.env.ADMIN_PASSWORD_HASH;

    const existing = await Storage.getUserByEmail(adminEmail);
    if (existing) {
      // If admin already exists in database, do not alter
      return;
    }

    if (!adminPassword && !adminPasswordHash) {
      // In production, admin credentials are not seeded if no environment variable is provided
      return;
    }

    const hash = adminPasswordHash || (await this.hashPassword(adminPassword));

    const adminRecord = {
      id: '010001',
      name: 'Shubham Singh',
      tag: '@ssgobind12',
      email: adminEmail,
      phoneNumber: '8573029430',
      countryCode: '+91',
      countryFlag: '🇮🇳',
      avatarColor: 0xFF7C3AED,
      avatarInitial: 'S',
      level: 50,
      coins: 99999,
      trophies: 999,
      role: 'admin',
      unlockedGameIds: ['tic_tac_toe', 'ludo', 'carrom', 'space_dodge', 'arena_brawl', 'word_rush'],
      passwordHash: hash,
      createdAt: new Date().toISOString()
    };

    await Storage.createUserAtomic(adminRecord);
    // Also alias alt email if memory mode
    if (adminAlt && adminAlt !== adminEmail) {
      const altRecord = { ...adminRecord, email: adminAlt };
      try {
        await Storage.createUserAtomic(altRecord);
      } catch {}
    }
  }
}

module.exports = AuthService;
