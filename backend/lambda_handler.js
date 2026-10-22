/**
 * Play Friends — Production AWS Lambda Handler
 * Deployable to AWS Lambda + API Gateway (ap-southeast-2)
 *
 * Implements:
 * - Unified routing for both API Gateway REST/HTTP paths and direct action payloads
 * - Scrypt password verification, atomic DynamoDB persistence, and Brevo email delivery
 * - Protected operations with verified session token authorization
 * - Error sanitization: never exposes internal database errors or stack traces to clients
 */

const AuthService = require('./auth_service');
const Storage = require('./storage');

function response(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization,X-Api-Key',
      'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS'
    },
    body: JSON.stringify(body)
  };
}

function extractBearerToken(event) {
  const headers = event.headers || {};
  const authHeader = headers['authorization'] || headers['Authorization'] || '';
  if (authHeader.startsWith('Bearer ')) {
    return authHeader.substring(7).trim();
  }
  return null;
}

exports.handler = async (event) => {
  // Handle HTTP OPTIONS for CORS preflight
  const httpMethod = (event.requestContext?.http?.method || event.httpMethod || '').toUpperCase();
  if (httpMethod === 'OPTIONS') {
    return response(204, {});
  }

  let body = {};
  if (event.body) {
    try {
      body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body;
    } catch {
      return response(400, { error: 'Invalid JSON request payload.' });
    }
  }

  // Determine path and route
  const rawPath = event.rawPath || event.path || body.path || '';
  const action = body.action || '';
  const sessionToken = extractBearerToken(event) || body.sessionToken;

  try {
    // -------------------------------------------------------------------------
    // 1. HEALTH / PING
    // -------------------------------------------------------------------------
    if (rawPath === '/ping' || action === 'ping') {
      return response(200, { status: 'ok', message: 'Play Friends AWS Backend Online' });
    }

    // -------------------------------------------------------------------------
    // 2. AUTHENTICATION & OTP
    // -------------------------------------------------------------------------
    if (rawPath === '/api/v1/auth/otp/request' || action === 'requestOtp') {
      const res = await AuthService.requestOtp({
        email: body.email,
        purpose: body.purpose,
        name: body.name
      });
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/auth/otp/verify' || action === 'verifyOtp') {
      const res = await AuthService.verifyOtp({
        email: body.email,
        otp: body.otp,
        purpose: body.purpose
      });
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/auth/register' || action === 'register') {
      const res = await AuthService.registerUser(body);
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/auth/login' || action === 'login') {
      const res = await AuthService.loginUser({
        identifier: body.identifier || body.email || body.phoneNumber,
        password: body.password
      });
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/auth/session/validate' || action === 'validateSession') {
      const token = sessionToken || body.token;
      const res = await AuthService.validateSession(token);
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/auth/logout' || action === 'logout') {
      const token = sessionToken || body.token;
      const res = await AuthService.logoutUser(token);
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/auth/password-reset' || action === 'passwordReset') {
      const res = await AuthService.resetPassword({
        email: body.email,
        newPassword: body.newPassword,
        verificationToken: body.verificationToken
      });
      return response(res.statusCode, res);
    }

    // -------------------------------------------------------------------------
    // 3. USER MANAGEMENT & UNIQUENESS
    // -------------------------------------------------------------------------
    if (rawPath === '/api/v1/user/check' || action === 'checkUser') {
      const res = await AuthService.checkUserExists({
        email: body.email,
        phoneNumber: body.phoneNumber
      });
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/user/profile-photo' || action === 'updateProfilePhoto' || action === 'deleteProfilePhoto') {
      const isDelete = action === 'deleteProfilePhoto' || httpMethod === 'DELETE';
      const photo = isDelete ? null : body.profilePhoto;
      const res = await AuthService.updateProfilePhoto({
        sessionToken,
        profilePhoto: photo,
        targetEmail: body.email
      });
      return response(res.statusCode, res);
    }

    // -------------------------------------------------------------------------
    // 4. SONGS
    // -------------------------------------------------------------------------
    if (rawPath === '/api/v1/songs/upload' || action === 'uploadSong') {
      const res = await AuthService.uploadSong({
        sessionToken,
        song: body.song || body
      });
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/songs/delete' || action === 'deleteSong') {
      const res = await AuthService.deleteSong({
        sessionToken,
        songId: body.songId
      });
      return response(res.statusCode, res);
    }

    if (rawPath === '/api/v1/songs/list' || action === 'getUserSongs') {
      const res = await AuthService.getUserSongs({
        userId: body.userId,
        sessionToken
      });
      return response(res.statusCode, res);
    }

    // -------------------------------------------------------------------------
    // 5. ROOMS (Real, Verified Live Rooms — No Demos)
    // -------------------------------------------------------------------------
    if (action === 'joinRoom') {
      const res = await Storage.joinRoom({ roomId: body.roomId || body.id, user: body.user });
      return response(res.success ? 200 : 400, res);
    }

    if (action === 'leaveRoom') {
      const res = await Storage.leaveRoom({ roomId: body.roomId || body.id, userId: body.userId });
      return response(res.success ? 200 : 400, res);
    }

    if (action === 'getRoomMembers') {
      const members = await Storage.getRoomMembers(body.roomId || body.id);
      return response(200, { success: true, members, currentPlayers: members.length });
    }

    if (rawPath === '/api/v1/rooms' || action === 'getRooms') {
      if (httpMethod === 'POST' || action === 'createRoom') {
        const room = body.room || body;
        await Storage.saveRoom(room);
        return response(201, { success: true, room });
      }
      const rooms = await Storage.getRooms();
      return response(200, rooms);
    }

    if (rawPath.startsWith('/api/v1/rooms/') || action === 'deleteRoom') {
      const roomId = body.roomId || rawPath.split('/').pop();
      await Storage.deleteRoom(roomId);
      return response(200, { success: true });
    }

    if (rawPath === '/api/v1/rooms/purge-demos' || action === 'purgeDemoRooms') {
      await Storage.purgeDemoRooms();
      return response(200, { success: true, message: 'All demo rooms purged.' });
    }

    // -------------------------------------------------------------------------
    // 6. USER SEARCH & SOCIAL GRAPH
    // -------------------------------------------------------------------------
    if (rawPath === '/api/v1/users/search' || action === 'searchUsers') {
      const q = event.queryStringParameters?.q || body.query || body.q || '';
      const results = await Storage.searchUsers(q);
      return response(200, results);
    }

    if (rawPath === '/api/v1/users/follow' || action === 'followUser') {
      const result = await Storage.followUser({
        followerEmail: body.followerEmail,
        followerName: body.followerName,
        targetGamerTagOrId: body.targetGamerTagOrId,
        follow: body.follow !== false
      });
      return response(200, result);
    }

    if (action === 'getFollowers') {
      const list = await Storage.getFollowers(body.userId || body.id || body.email);
      return response(200, { success: true, list, count: list.length });
    }

    if (action === 'getFollowing') {
      const list = await Storage.getFollowing(body.userId || body.id || body.email);
      return response(200, { success: true, list, count: list.length });
    }

    if (action === 'getFollowStatus') {
      const res = await Storage.getFollowStatus(body.currentUserId || body.userId, body.targetUserId || body.targetId);
      return response(200, res);
    }

    return response(404, { error: `Not found: action=${action || 'none'}, path=${rawPath || 'none'}` });
  } catch (err) {
    console.error('Lambda unhandled error:', err.message);
    // Never leak stack trace or internal database details to clients
    return response(500, { error: 'An unexpected internal server error occurred.' });
  }
};
