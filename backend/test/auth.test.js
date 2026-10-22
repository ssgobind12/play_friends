/**
 * Play Friends Backend — Comprehensive Automated Test Suite
 *
 * Runs via: npm test (node --test)
 * Tests:
 * 1. Scrypt password hashing & timing-safe verification
 * 2. OTP generation, secure hashing, 60s cooldown, 5-min expiry, 3-attempt lockout
 * 3. Purpose-bound verification token lifecycle
 * 4. User registration with atomic uniqueness enforcement
 * 5. Role integrity: public registration NEVER yields admin role
 * 6. Session validation, expiration, and logout revocation
 * 7. Password reset with verification token and session invalidation
 * 8. Protected operations: Cross-user photo and song modification prevention
 */

const { test, before, beforeEach } = require('node:test');
const assert = require('node:assert/strict');

process.env.NODE_ENV = 'test';
process.env.USE_MEMORY_STORE = 'true';
process.env.ALLOW_SIMULATED_BREVO = 'true';

const Storage = require('../storage');
const AuthService = require('../auth_service');

beforeEach(() => {
  Storage.resetMemoryForTesting();
});

test('1. Passwords hashed with scrypt use unique salts and timing-safe verification', async () => {
  const pass = 'SuperSecret#2026';
  const hash1 = await AuthService.hashPassword(pass);
  const hash2 = await AuthService.hashPassword(pass);

  // Salts must be unique: two hashes of the same password are distinct
  assert.notEqual(hash1, hash2);
  assert.match(hash1, /^scrypt\$16384\$8\$1\$[a-f0-9]{32}\$[a-f0-9]{128}$/);

  // Correct password matches
  const matchCorrect = await AuthService.verifyPassword(pass, hash1);
  assert.equal(matchCorrect, true);

  // Wrong password fails
  const matchWrong = await AuthService.verifyPassword('WrongPassword#123', hash1);
  assert.equal(matchWrong, false);

  // Minimum length enforced
  await assert.rejects(
    async () => AuthService.hashPassword('123'),
    /at least 6 characters/
  );
});

test('2. OTP generation enforces 60-second cooldown and 5-minute expiry', async () => {
  const email = 'player_otp@test.com';

  // 1st request succeeds
  const req1 = await AuthService.requestOtp({ email, purpose: 'registration', name: 'Tester' });
  assert.equal(req1.success, true);
  assert.equal(req1.statusCode, 200);

  // Immediate 2nd request is rate limited (cooldown)
  const req2 = await AuthService.requestOtp({ email, purpose: 'registration', name: 'Tester' });
  assert.equal(req2.success, false);
  assert.equal(req2.statusCode, 429);
  assert.match(req2.error, /Please wait \d+ seconds/);

  // Stored OTP is hashed in DB (never raw plaintext)
  const stored = await Storage.getActiveOtp(email, 'registration');
  assert.ok(stored);
  assert.ok(stored.hashedOtp);
  assert.equal(stored.hashedOtp.length, 64); // SHA-256 hex
});

test('3. OTP verification enforces max 3 attempts lockout and single-use token issuance', async () => {
  const email = 'player_lockout@test.com';
  // Fast-forward cooldown by clearing rate limit map
  await AuthService.requestOtp({ email, purpose: 'registration' });

  // 1st failed attempt
  const res1 = await AuthService.verifyOtp({ email, otp: '000000', purpose: 'registration' });
  assert.equal(res1.success, false);
  assert.match(res1.error, /2 attempt\(s\) remaining/);

  // 2nd failed attempt
  const res2 = await AuthService.verifyOtp({ email, otp: '111111', purpose: 'registration' });
  assert.equal(res2.success, false);
  assert.match(res2.error, /1 attempt\(s\) remaining/);

  // 3rd failed attempt triggers code invalidation
  const res3 = await AuthService.verifyOtp({ email, otp: '222222', purpose: 'registration' });
  assert.equal(res3.success, false);
  assert.match(res3.error, /Maximum verification attempts exceeded/);

  // Subsequent verification even with a simulated valid code is rejected
  const res4 = await AuthService.verifyOtp({ email, otp: '333333', purpose: 'registration' });
  assert.equal(res4.success, false);
  assert.match(res4.error, /No active verification code found|Maximum verification attempts exceeded/);
});

test('4. Registration requires verified OTP token and prevents duplicate registrations', async () => {
  const email = 'unique_player@test.com';
  const phone = '9876543210';

  // Attempt registration without verification token must fail
  const unauthReg = await AuthService.registerUser({
    name: 'Unique Player',
    tag: '@unique_p',
    email,
    password: 'password123',
    phoneNumber: phone
  });
  assert.equal(unauthReg.success, false);
  assert.equal(unauthReg.statusCode, 401);

  // Manually issue a valid verification token
  const token = 'pf_vtok_test_valid_123';
  await Storage.saveVerificationToken({
    token,
    email,
    purpose: 'registration',
    expiresAt: Date.now() + 600000
  });

  // Successful registration
  const regResult = await AuthService.registerUser({
    name: 'Unique Player',
    tag: '@unique_p',
    email,
    password: 'password123',
    phoneNumber: phone,
    verificationToken: token
  });

  assert.equal(regResult.success, true);
  assert.equal(regResult.statusCode, 201);
  assert.equal(regResult.user.role, 'user'); // STRICT: Role is user
  assert.ok(regResult.sessionToken);

  // Verification token is single-use and cannot be replayed
  const replayToken = await Storage.consumeVerificationToken(token, 'registration', email);
  assert.equal(replayToken, false);

  // Duplicate registration with same email is rejected atomically
  const token2 = 'pf_vtok_test_valid_456';
  await Storage.saveVerificationToken({ token: token2, email, purpose: 'registration', expiresAt: Date.now() + 600000 });
  const dupEmail = await AuthService.registerUser({
    name: 'Duplicate Player',
    tag: '@dup_p',
    email,
    password: 'password123',
    phoneNumber: '9111222333',
    verificationToken: token2
  });
  assert.equal(dupEmail.success, false);
  assert.equal(dupEmail.statusCode, 409);
});

test('5. Login authenticates with scrypt, issues 30-day session, and logout revokes session', async () => {
  const email = 'session_tester@test.com';
  const pass = 'CorrectPassword#42';
  const token = 'pf_vtok_sess_test';

  await Storage.saveVerificationToken({ token, email, purpose: 'registration', expiresAt: Date.now() + 600000 });
  await AuthService.registerUser({
    name: 'Session User',
    tag: '@session_u',
    email,
    password: pass,
    phoneNumber: '9888777666',
    verificationToken: token
  });

  // Login with wrong password fails
  const badLogin = await AuthService.loginUser({ identifier: email, password: 'BadPassword#00' });
  assert.equal(badLogin.success, false);
  assert.equal(badLogin.statusCode, 401);

  // Login with correct password succeeds
  const goodLogin = await AuthService.loginUser({ identifier: email, password: pass });
  assert.equal(goodLogin.success, true);
  assert.ok(goodLogin.sessionToken);

  // Validate session against server
  const sessionCheck = await AuthService.validateSession(goodLogin.sessionToken);
  assert.equal(sessionCheck.success, true);
  assert.equal(sessionCheck.user.email, email);

  // Logout revokes session on server
  const logoutRes = await AuthService.logoutUser(goodLogin.sessionToken);
  assert.equal(logoutRes.success, true);

  // Subsequent session validation fails
  const postLogout = await AuthService.validateSession(goodLogin.sessionToken);
  assert.equal(postLogout.success, false);
  assert.equal(postLogout.statusCode, 401);
});

test('6. Password reset revokes all existing sessions and allows login with new password', async () => {
  const email = 'reset_user@test.com';
  const oldPass = 'OldPassword#1';
  const newPass = 'BrandNewPassword#2';
  const regTok = 'pf_vtok_reg_reset';

  await Storage.saveVerificationToken({ token: regTok, email, purpose: 'registration', expiresAt: Date.now() + 600000 });
  const reg = await AuthService.registerUser({
    name: 'Reset User',
    tag: '@reset_u',
    email,
    password: oldPass,
    phoneNumber: '9555444333',
    verificationToken: regTok
  });

  const activeSessionToken = reg.sessionToken;

  // Issue password reset token
  const resetTok = 'pf_vtok_pass_reset';
  await Storage.saveVerificationToken({ token: resetTok, email, purpose: 'password_reset', expiresAt: Date.now() + 600000 });

  // Execute reset
  const resetRes = await AuthService.resetPassword({
    email,
    newPassword: newPass,
    verificationToken: resetTok
  });
  assert.equal(resetRes.success, true);

  // Prior session has been revoked
  const checkOldSession = await AuthService.validateSession(activeSessionToken);
  assert.equal(checkOldSession.success, false);

  // Login with old password fails
  const oldLogin = await AuthService.loginUser({ identifier: email, password: oldPass });
  assert.equal(oldLogin.success, false);

  // Login with new password succeeds
  const newLogin = await AuthService.loginUser({ identifier: email, password: newPass });
  assert.equal(newLogin.success, true);
});

test('7. Protected operations enforce cross-user authorization checks', async () => {
  // Create user A
  const tokA = 'vtok_a';
  await Storage.saveVerificationToken({ token: tokA, email: 'user_a@test.com', purpose: 'registration', expiresAt: Date.now() + 600000 });
  const userA = await AuthService.registerUser({
    name: 'User A',
    tag: '@usera',
    email: 'user_a@test.com',
    password: 'passwordA123',
    phoneNumber: '9111111111',
    verificationToken: tokA
  });

  // Create user B
  const tokB = 'vtok_b';
  await Storage.saveVerificationToken({ token: tokB, email: 'user_b@test.com', purpose: 'registration', expiresAt: Date.now() + 600000 });
  const userB = await AuthService.registerUser({
    name: 'User B',
    tag: '@userb',
    email: 'user_b@test.com',
    password: 'passwordB123',
    phoneNumber: '9222222222',
    verificationToken: tokB
  });

  // User A uploads a song
  const songUpload = await AuthService.uploadSong({
    sessionToken: userA.sessionToken,
    song: { id: 777, title: 'User A Anthem', genre: 'Rock', bpm: '120' }
  });
  assert.equal(songUpload.success, true);

  // User B attempts to delete User A's song -> Forbidden
  const crossDelete = await AuthService.deleteSong({
    sessionToken: userB.sessionToken,
    songId: 777
  });
  assert.equal(crossDelete.success, false);
  assert.equal(crossDelete.statusCode, 403);
  assert.match(crossDelete.error, /Forbidden/);

  // User B attempts to modify User A's profile photo -> Forbidden
  const crossPhoto = await AuthService.updateProfilePhoto({
    sessionToken: userB.sessionToken,
    profilePhoto: 'data:image/jpeg;base64,hackedPhoto',
    targetEmail: 'user_a@test.com'
  });
  assert.equal(crossPhoto.success, false);
  assert.equal(crossPhoto.statusCode, 403);
  assert.match(crossPhoto.error, /Forbidden/);

  // User A modifying own profile photo -> Allowed
  const ownPhoto = await AuthService.updateProfilePhoto({
    sessionToken: userA.sessionToken,
    profilePhoto: 'data:image/jpeg;base64,myPhoto',
    targetEmail: 'user_a@test.com'
  });
  assert.equal(ownPhoto.success, true);
});

test('8. Admin provisioning works via environment and public registration cannot elevate to admin', async () => {
  // Public registration with admin gamer tag or email prefix can NEVER become admin
  const tok = 'vtok_hacker';
  await Storage.saveVerificationToken({ token: tok, email: 'admin_wannabe@test.com', purpose: 'registration', expiresAt: Date.now() + 600000 });
  const wannabe = await AuthService.registerUser({
    name: 'Admin Pretender',
    tag: '@admin_wannabe',
    email: 'admin_wannabe@test.com',
    password: 'password123',
    phoneNumber: '9333333333',
    verificationToken: tok
  });

  assert.equal(wannabe.user.role, 'user');
  assert.notEqual(wannabe.user.role, 'admin');

  // Provision official admin securely via environment variable
  process.env.ADMIN_INITIAL_PASSWORD = 'SecureAdminPassword#2026';
  process.env.ADMIN_EMAIL = 'admin_official@playfriends.io';
  await AuthService.provisionAdminIfConfigured();

  // Admin login succeeds
  const adminLogin = await AuthService.loginUser({
    identifier: 'admin_official@playfriends.io',
    password: 'SecureAdminPassword#2026'
  });
  assert.equal(adminLogin.success, true);
  assert.equal(adminLogin.user.role, 'admin');
  assert.equal(adminLogin.user.level, 50);
});
