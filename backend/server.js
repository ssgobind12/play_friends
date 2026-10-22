/**
 * Play Friends — Production Trusted Express REST API
 *
 * Implements:
 * - Canonical REST routes matching API Gateway
 * - Scrypt password verification, session validation, and Brevo email delivery
 * - Protected operations with verified session token authorization
 * - Error sanitization: never exposes internal database errors or stack traces to clients
 */

const express = require('express');
const cors = require('cors');
require('dotenv').config();

const AuthService = require('./auth_service');

const app = express();
app.use(cors());
app.use(express.json({ limit: '5mb' }));

const PORT = process.env.PORT || 3000;

function extractBearerToken(req) {
  const authHeader = req.headers['authorization'];
  if (authHeader && authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  return req.body?.sessionToken || null;
}

// -----------------------------------------------------------------------------
// 1. HEALTH / PING
// -----------------------------------------------------------------------------
app.get('/ping', (req, res) => {
  res.json({ status: 'ok', message: 'Play Friends Server Online' });
});

app.post('/ping', (req, res) => {
  res.json({ status: 'ok', message: 'Play Friends Server Online' });
});

// -----------------------------------------------------------------------------
// 2. AUTHENTICATION & OTP
// -----------------------------------------------------------------------------
app.post('/api/v1/auth/otp/request', async (req, res) => {
  try {
    const result = await AuthService.requestOtp({
      email: req.body.email,
      purpose: req.body.purpose,
      name: req.body.name
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/auth/otp/request:', err.message);
    res.status(500).json({ error: 'Failed to process OTP request.' });
  }
});

app.post('/api/v1/auth/otp/verify', async (req, res) => {
  try {
    const result = await AuthService.verifyOtp({
      email: req.body.email,
      otp: req.body.otp,
      purpose: req.body.purpose
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/auth/otp/verify:', err.message);
    res.status(500).json({ error: 'Failed to verify OTP.' });
  }
});

app.post('/api/v1/auth/register', async (req, res) => {
  try {
    const result = await AuthService.registerUser(req.body);
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/auth/register:', err.message);
    res.status(500).json({ error: 'Failed to complete registration.' });
  }
});

app.post('/api/v1/auth/login', async (req, res) => {
  try {
    const result = await AuthService.loginUser({
      identifier: req.body.identifier || req.body.email || req.body.phoneNumber,
      password: req.body.password
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/auth/login:', err.message);
    res.status(500).json({ error: 'Failed to authenticate user.' });
  }
});

app.post('/api/v1/auth/session/validate', async (req, res) => {
  try {
    const token = extractBearerToken(req);
    const result = await AuthService.validateSession(token);
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/auth/session/validate:', err.message);
    res.status(500).json({ error: 'Failed to validate session.' });
  }
});

app.post('/api/v1/auth/logout', async (req, res) => {
  try {
    const token = extractBearerToken(req);
    const result = await AuthService.logoutUser(token);
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/auth/logout:', err.message);
    res.status(500).json({ error: 'Failed to process logout.' });
  }
});

app.post('/api/v1/auth/password-reset', async (req, res) => {
  try {
    const result = await AuthService.resetPassword({
      email: req.body.email,
      newPassword: req.body.newPassword,
      verificationToken: req.body.verificationToken
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/auth/password-reset:', err.message);
    res.status(500).json({ error: 'Failed to reset password.' });
  }
});

// -----------------------------------------------------------------------------
// 3. USER MANAGEMENT & UNIQUENESS
// -----------------------------------------------------------------------------
app.post('/api/v1/user/check', async (req, res) => {
  try {
    const result = await AuthService.checkUserExists({
      email: req.body.email,
      phoneNumber: req.body.phoneNumber
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/user/check:', err.message);
    res.status(500).json({ error: 'Failed to verify account uniqueness.' });
  }
});

app.post('/api/v1/user/profile-photo', async (req, res) => {
  try {
    const sessionToken = extractBearerToken(req);
    const result = await AuthService.updateProfilePhoto({
      sessionToken,
      profilePhoto: req.body.profilePhoto,
      targetEmail: req.body.email
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/user/profile-photo:', err.message);
    res.status(500).json({ error: 'Failed to update profile photo.' });
  }
});

app.delete('/api/v1/user/profile-photo', async (req, res) => {
  try {
    const sessionToken = extractBearerToken(req);
    const result = await AuthService.updateProfilePhoto({
      sessionToken,
      profilePhoto: null,
      targetEmail: req.body.email
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error DELETE /api/v1/user/profile-photo:', err.message);
    res.status(500).json({ error: 'Failed to delete profile photo.' });
  }
});

// -----------------------------------------------------------------------------
// 4. SONGS
// -----------------------------------------------------------------------------
app.post('/api/v1/songs/upload', async (req, res) => {
  try {
    const sessionToken = extractBearerToken(req);
    const result = await AuthService.uploadSong({
      sessionToken,
      song: req.body.song || req.body
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/songs/upload:', err.message);
    res.status(500).json({ error: 'Failed to upload song.' });
  }
});

app.delete('/api/v1/songs/:songId', async (req, res) => {
  try {
    const sessionToken = extractBearerToken(req);
    const result = await AuthService.deleteSong({
      sessionToken,
      songId: req.params.songId
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/songs/:songId:', err.message);
    res.status(500).json({ error: 'Failed to delete song.' });
  }
});

app.get('/api/v1/songs/:userId', async (req, res) => {
  try {
    const sessionToken = extractBearerToken(req);
    const result = await AuthService.getUserSongs({
      userId: req.params.userId,
      sessionToken
    });
    res.status(result.statusCode).json(result);
  } catch (err) {
    console.error('Route error /api/v1/songs/:userId:', err.message);
    res.status(500).json({ error: 'Failed to fetch user songs.' });
  }
});

// -----------------------------------------------------------------------------
// 5. LEGACY ACTION DISPATCH (COMPATIBILITY ROUTE)
// -----------------------------------------------------------------------------
app.post('/', async (req, res) => {
  const action = req.body?.action;
  const sessionToken = extractBearerToken(req);

  try {
    if (action === 'ping') {
      return res.json({ status: 'ok', message: 'Play Friends AWS Backend Online' });
    }
    if (action === 'checkUser') {
      const result = await AuthService.checkUserExists(req.body);
      return res.status(result.statusCode).json(result);
    }
    if (action === 'register') {
      const result = await AuthService.registerUser(req.body);
      return res.status(result.statusCode).json(result);
    }
    if (action === 'login') {
      const result = await AuthService.loginUser({
        identifier: req.body.identifier || req.body.email || req.body.phoneNumber,
        password: req.body.password
      });
      return res.status(result.statusCode).json(result);
    }
    if (action === 'validateSession') {
      const result = await AuthService.validateSession(sessionToken || req.body.token);
      return res.status(result.statusCode).json(result);
    }
    if (action === 'logout') {
      const result = await AuthService.logoutUser(sessionToken || req.body.token);
      return res.status(result.statusCode).json(result);
    }
    if (action === 'updateProfilePhoto' || action === 'deleteProfilePhoto') {
      const photo = action === 'deleteProfilePhoto' ? null : req.body.profilePhoto;
      const result = await AuthService.updateProfilePhoto({
        sessionToken,
        profilePhoto: photo,
        targetEmail: req.body.email
      });
      return res.status(result.statusCode).json(result);
    }
    if (action === 'uploadSong') {
      const result = await AuthService.uploadSong({
        sessionToken,
        song: req.body.song || req.body
      });
      return res.status(result.statusCode).json(result);
    }
    if (action === 'deleteSong') {
      const result = await AuthService.deleteSong({
        sessionToken,
        songId: req.body.songId
      });
      return res.status(result.statusCode).json(result);
    }
    if (action === 'getUserSongs') {
      const result = await AuthService.getUserSongs({
        userId: req.body.userId,
        sessionToken
      });
      return res.status(result.statusCode).json(result);
    }

    return res.status(404).json({ error: `Unknown action: ${action}` });
  } catch (err) {
    console.error('Legacy route error:', err.message);
    return res.status(500).json({ error: 'Internal server error.' });
  }
});

// Initialize administrator if configured via environment variable
AuthService.provisionAdminIfConfigured().catch((err) => {
  console.error('Admin provisioning error:', err.message);
});

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Play Friends trusted backend listening on port ${PORT}`);
  });
}

module.exports = app;
