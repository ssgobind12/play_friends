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
// 5. LIVE ROOMS API
// -----------------------------------------------------------------------------
app.get('/api/v1/rooms', async (req, res) => {
  try {
    const rooms = await Storage.getRooms();
    res.json(rooms);
  } catch (err) {
    console.error('Route error GET /api/v1/rooms:', err.message);
    res.status(500).json({ error: 'Failed to fetch rooms.' });
  }
});

app.post('/api/v1/rooms', async (req, res) => {
  try {
    const room = req.body;
    if (!room || !room.id) {
      return res.status(400).json({ error: 'Room data and id required.' });
    }
    await Storage.saveRoom(room);
    res.status(201).json({ success: true, room });
  } catch (err) {
    console.error('Route error POST /api/v1/rooms:', err.message);
    res.status(500).json({ error: 'Failed to save room.' });
  }
});

app.delete('/api/v1/rooms/:roomId', async (req, res) => {
  try {
    const { roomId } = req.params;
    await Storage.deleteRoom(roomId);
    res.json({ success: true });
  } catch (err) {
    console.error('Route error DELETE /api/v1/rooms:', err.message);
    res.status(500).json({ error: 'Failed to delete room.' });
  }
});

app.post('/api/v1/rooms/purge-demos', async (req, res) => {
  try {
    await Storage.purgeDemoRooms();
    res.json({ success: true, message: 'All demo and fake live rooms purged.' });
  } catch (err) {
    console.error('Route error /api/v1/rooms/purge-demos:', err.message);
    res.status(500).json({ error: 'Failed to purge demo rooms.' });
  }
});

app.post('/api/v1/rooms/:roomId/join', async (req, res) => {
  try {
    const { roomId } = req.params;
    const user = req.body.user || req.body;
    const result = await Storage.joinRoom({ roomId, user });
    res.status(result.success ? 200 : 400).json(result);
  } catch (err) {
    console.error('Route error POST /api/v1/rooms/:roomId/join:', err.message);
    res.status(500).json({ error: 'Failed to join room.' });
  }
});

app.post('/api/v1/rooms/:roomId/leave', async (req, res) => {
  try {
    const { roomId } = req.params;
    const userId = req.body.userId || req.body.user?.id;
    const result = await Storage.leaveRoom({ roomId, userId });
    res.status(result.success ? 200 : 400).json(result);
  } catch (err) {
    console.error('Route error POST /api/v1/rooms/:roomId/leave:', err.message);
    res.status(500).json({ error: 'Failed to leave room.' });
  }
});

app.get('/api/v1/rooms/:roomId/members', async (req, res) => {
  try {
    const { roomId } = req.params;
    const members = await Storage.getRoomMembers(roomId);
    res.json({ success: true, members, currentPlayers: members.length });
  } catch (err) {
    console.error('Route error GET /api/v1/rooms/:roomId/members:', err.message);
    res.status(500).json({ error: 'Failed to get room members.' });
  }
});

// -----------------------------------------------------------------------------
// 6. USER SEARCH & SOCIAL GRAPH (FOLLOWERS & FOLLOWING)
// -----------------------------------------------------------------------------
app.get('/api/v1/users/search', async (req, res) => {
  try {
    const query = req.query.q || '';
    const results = await Storage.searchUsers(query);
    res.json(results);
  } catch (err) {
    console.error('Route error GET /api/v1/users/search:', err.message);
    res.status(500).json({ error: 'Failed to search users.' });
  }
});

app.post('/api/v1/users/follow', async (req, res) => {
  try {
    const { followerEmail, followerName, targetGamerTagOrId, follow } = req.body;
    const result = await Storage.followUser({
      followerEmail,
      followerName,
      targetGamerTagOrId,
      follow: follow !== false
    });
    res.json(result);
  } catch (err) {
    console.error('Route error POST /api/v1/users/follow:', err.message);
    res.status(500).json({ error: 'Failed to update follow status.' });
  }
});

app.get('/api/v1/users/:userId/followers', async (req, res) => {
  try {
    const { userId } = req.params;
    const list = await Storage.getFollowers(userId);
    res.json({ success: true, list, count: list.length });
  } catch (err) {
    console.error('Route error GET /api/v1/users/:userId/followers:', err.message);
    res.status(500).json({ error: 'Failed to get followers.' });
  }
});

app.get('/api/v1/users/:userId/following', async (req, res) => {
  try {
    const { userId } = req.params;
    const list = await Storage.getFollowing(userId);
    res.json({ success: true, list, count: list.length });
  } catch (err) {
    console.error('Route error GET /api/v1/users/:userId/following:', err.message);
    res.status(500).json({ error: 'Failed to get following.' });
  }
});

app.get('/api/v1/users/:userId/follow-status', async (req, res) => {
  try {
    const { userId } = req.params;
    const targetUserId = req.query.targetUserId || req.query.targetId;
    const status = await Storage.getFollowStatus(userId, targetUserId);
    res.json(status);
  } catch (err) {
    console.error('Route error GET /api/v1/users/:userId/follow-status:', err.message);
    res.status(500).json({ error: 'Failed to get follow status.' });
  }
});

// -----------------------------------------------------------------------------
// 7. LEGACY ACTION DISPATCH (COMPATIBILITY ROUTE)
// -----------------------------------------------------------------------------
app.post('/', async (req, res) => {
  const action = req.body?.action;
  const sessionToken = extractBearerToken(req);

  try {
    if (action === 'searchUsers') {
      const results = await Storage.searchUsers(req.body.query || req.body.q);
      return res.json(results);
    }
    if (action === 'followUser') {
      const result = await Storage.followUser(req.body);
      return res.json(result);
    }
    if (action === 'getFollowers') {
      const list = await Storage.getFollowers(req.body.userId || req.body.id || req.body.email);
      return res.json({ success: true, list, count: list.length });
    }
    if (action === 'getFollowing') {
      const list = await Storage.getFollowing(req.body.userId || req.body.id || req.body.email);
      return res.json({ success: true, list, count: list.length });
    }
    if (action === 'getFollowStatus') {
      const status = await Storage.getFollowStatus(req.body.currentUserId || req.body.userId, req.body.targetUserId || req.body.targetId);
      return res.json(status);
    }
    if (action === 'joinRoom') {
      const result = await Storage.joinRoom({ roomId: req.body.roomId || req.body.id, user: req.body.user });
      return res.status(result.success ? 200 : 400).json(result);
    }
    if (action === 'leaveRoom') {
      const result = await Storage.leaveRoom({ roomId: req.body.roomId || req.body.id, userId: req.body.userId });
      return res.status(result.success ? 200 : 400).json(result);
    }
    if (action === 'getRoomMembers') {
      const members = await Storage.getRoomMembers(req.body.roomId || req.body.id);
      return res.json({ success: true, members, currentPlayers: members.length });
    }
    if (action === 'purgeDemoRooms') {
      await Storage.purgeDemoRooms();
      return res.json({ success: true });
    }
    if (action === 'getRooms') {
      const rooms = await Storage.getRooms();
      return res.json(rooms);
    }
    if (action === 'createRoom') {
      const room = req.body.room || req.body;
      await Storage.saveRoom(room);
      return res.json({ success: true, room });
    }
    if (action === 'deleteRoom') {
      await Storage.deleteRoom(req.body.roomId);
      return res.json({ success: true });
    }
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
