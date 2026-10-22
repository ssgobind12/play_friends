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

    return response(404, { error: `Not found: action=${action || 'none'}, path=${rawPath || 'none'}` });
  } catch (err) {
    console.error('Lambda unhandled error:', err.message);
    // Never leak stack trace or internal database details to clients
    return response(500, { error: 'An unexpected internal server error occurred.' });
  }
};
