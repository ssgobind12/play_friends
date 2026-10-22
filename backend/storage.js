/**
 * Play Friends — Storage Repository
 *
 * Implements persistent storage using AWS DynamoDB DocumentClient with:
 * - Atomic conditional writes (attribute_not_exists) to prevent race conditions
 * - Safe UpdateCommand operations for profile photos (never overwriting user records)
 * - Session token management with expiration
 * - Hashed OTP storage
 * - Test/in-memory adapter for local development and test execution
 */

const crypto = require('crypto');

// Check if running in test / memory mode
const USE_MEMORY_STORE = process.env.NODE_ENV === 'test' || process.env.USE_MEMORY_STORE === 'true';

let docClient = null;
let PutCommand, GetCommand, UpdateCommand, DeleteCommand, ScanCommand;

if (!USE_MEMORY_STORE) {
  try {
    const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
    const docPkg = require('@aws-sdk/lib-dynamodb');
    PutCommand = docPkg.PutCommand;
    GetCommand = docPkg.GetCommand;
    UpdateCommand = docPkg.UpdateCommand;
    DeleteCommand = docPkg.DeleteCommand;
    ScanCommand = docPkg.ScanCommand;

    const ddbClient = new DynamoDBClient({
      region: process.env.AWS_REGION || 'ap-southeast-2'
    });
    docClient = docPkg.DynamoDBDocumentClient.from(ddbClient);
  } catch (err) {
    // If AWS SDK cannot initialize, fallback to memory store with warning
    console.warn('[STORAGE] AWS SDK unavailable or unconfigured, falling back to in-memory store:', err.message);
  }
}

const TABLE_USERS = process.env.TABLE_NAME || 'PlayFriends_Users';
const TABLE_SESSIONS = `${TABLE_USERS}_Sessions`;
const TABLE_OTPS = `${TABLE_USERS}_Otps`;
const TABLE_TOKENS = `${TABLE_USERS}_Tokens`;
const TABLE_SONGS = `${TABLE_USERS}_Songs`;
const TABLE_ROOMS = `${TABLE_USERS}_Rooms`;

// -----------------------------------------------------------------------------
// IN-MEMORY DATA STORE (FOR TESTING / LOCAL DEV)
// -----------------------------------------------------------------------------
const memUsers = new Map();
const memSessions = new Map();
const memOtps = new Map();
const memTokens = new Map();
const memSongs = new Map();
const memRooms = new Map();

class Storage {
  static isMemoryMode() {
    return USE_MEMORY_STORE || docClient == null;
  }

  static resetMemoryForTesting() {
    memUsers.clear();
    memSessions.clear();
    memOtps.clear();
    memTokens.clear();
    memSongs.clear();
    memRooms.clear();
  }

  // ---------------------------------------------------------------------------
  // USERS
  // ---------------------------------------------------------------------------

  static async getUserByEmail(email) {
    const cleanEmail = (email || '').toLowerCase().trim();
    if (this.isMemoryMode()) {
      const u = memUsers.get(cleanEmail);
      return u ? { ...u } : null;
    }

    try {
      const res = await docClient.send(new GetCommand({
        TableName: TABLE_USERS,
        Key: { email: cleanEmail }
      }));
      return res.Item || null;
    } catch (err) {
      console.error('Storage getUserByEmail error:', err.message);
      throw err;
    }
  }

  static async getUserByPhone(phoneNumber) {
    const cleanPhone = (phoneNumber || '').replace(/\D/g, '');
    if (!cleanPhone) return null;

    if (this.isMemoryMode()) {
      for (const u of memUsers.values()) {
        if (u.phoneNumber && u.phoneNumber.replace(/\D/g, '') === cleanPhone) {
          return { ...u };
        }
      }
      return null;
    }

    try {
      const res = await docClient.send(new ScanCommand({
        TableName: TABLE_USERS,
        FilterExpression: 'phoneNumber = :p',
        ExpressionAttributeValues: { ':p': cleanPhone },
        Limit: 1
      }));
      return res.Items && res.Items.length > 0 ? res.Items[0] : null;
    } catch (err) {
      console.error('Storage getUserByPhone error:', err.message);
      throw err;
    }
  }

  static async createUserAtomic(userRecord) {
    const cleanEmail = (userRecord.email || '').toLowerCase().trim();
    const cleanPhone = (userRecord.phoneNumber || '').replace(/\D/g, '');

    if (this.isMemoryMode()) {
      if (memUsers.has(cleanEmail)) {
        const err = new Error('ConditionalCheckFailed: Email already registered');
        err.name = 'ConditionalCheckFailedException';
        throw err;
      }
      for (const u of memUsers.values()) {
        if (u.phoneNumber && u.phoneNumber.replace(/\D/g, '') === cleanPhone) {
          const err = new Error('ConditionalCheckFailed: Phone number already registered');
          err.name = 'ConditionalCheckFailedException';
          throw err;
        }
      }
      memUsers.set(cleanEmail, { ...userRecord });
      return { ...userRecord };
    }

    try {
      // Atomic conditional put: table must not contain this email already
      await docClient.send(new PutCommand({
        TableName: TABLE_USERS,
        Item: userRecord,
        ConditionExpression: 'attribute_not_exists(email)'
      }));
      return userRecord;
    } catch (err) {
      console.error('Storage createUserAtomic error:', err.message);
      throw err;
    }
  }

  static async updatePasswordHash(email, newPasswordHash) {
    const cleanEmail = (email || '').toLowerCase().trim();
    const updatedAt = new Date().toISOString();

    if (this.isMemoryMode()) {
      const u = memUsers.get(cleanEmail);
      if (!u) return false;
      u.passwordHash = newPasswordHash;
      u.updatedAt = updatedAt;
      return true;
    }

    try {
      await docClient.send(new UpdateCommand({
        TableName: TABLE_USERS,
        Key: { email: cleanEmail },
        UpdateExpression: 'SET passwordHash = :p, updatedAt = :u',
        ExpressionAttributeValues: {
          ':p': newPasswordHash,
          ':u': updatedAt
        }
      }));
      return true;
    } catch (err) {
      console.error('Storage updatePasswordHash error:', err.message);
      throw err;
    }
  }

  static async updateProfilePhoto(email, profilePhoto) {
    const cleanEmail = (email || '').toLowerCase().trim();
    const updatedAt = new Date().toISOString();

    if (this.isMemoryMode()) {
      const u = memUsers.get(cleanEmail);
      if (!u) return false;
      if (profilePhoto) {
        u.profilePhoto = profilePhoto;
      } else {
        delete u.profilePhoto;
      }
      u.updatedAt = updatedAt;
      return true;
    }

    try {
      if (profilePhoto) {
        // Safe UpdateCommand: modifies only profilePhoto and updatedAt, preserving all other fields
        await docClient.send(new UpdateCommand({
          TableName: TABLE_USERS,
          Key: { email: cleanEmail },
          UpdateExpression: 'SET profilePhoto = :photo, updatedAt = :updatedAt',
          ExpressionAttributeValues: {
            ':photo': profilePhoto,
            ':updatedAt': updatedAt
          }
        }));
      } else {
        await docClient.send(new UpdateCommand({
          TableName: TABLE_USERS,
          Key: { email: cleanEmail },
          UpdateExpression: 'REMOVE profilePhoto SET updatedAt = :updatedAt',
          ExpressionAttributeValues: {
            ':updatedAt': updatedAt
          }
        }));
      }
      return true;
    } catch (err) {
      console.error('Storage updateProfilePhoto error:', err.message);
      throw err;
    }
  }

  // ---------------------------------------------------------------------------
  // SESSIONS
  // ---------------------------------------------------------------------------

  static async saveSession(sessionRecord) {
    if (this.isMemoryMode()) {
      memSessions.set(sessionRecord.token, { ...sessionRecord });
      return true;
    }

    try {
      await docClient.send(new PutCommand({
        TableName: TABLE_SESSIONS,
        Item: sessionRecord
      }));
      return true;
    } catch (err) {
      console.error('Storage saveSession error:', err.message);
      throw err;
    }
  }

  static async getSession(token) {
    if (!token) return null;

    if (this.isMemoryMode()) {
      const s = memSessions.get(token);
      if (!s) return null;
      if (Date.now() > s.expiresAt) {
        memSessions.delete(token);
        return null;
      }
      return { ...s };
    }

    try {
      const res = await docClient.send(new GetCommand({
        TableName: TABLE_SESSIONS,
        Key: { token }
      }));
      const item = res.Item;
      if (!item) return null;
      if (Date.now() > item.expiresAt) {
        await this.deleteSession(token);
        return null;
      }
      return item;
    } catch (err) {
      console.error('Storage getSession error:', err.message);
      throw err;
    }
  }

  static async deleteSession(token) {
    if (!token) return true;

    if (this.isMemoryMode()) {
      memSessions.delete(token);
      return true;
    }

    try {
      await docClient.send(new DeleteCommand({
        TableName: TABLE_SESSIONS,
        Key: { token }
      }));
      return true;
    } catch (err) {
      console.error('Storage deleteSession error:', err.message);
      throw err;
    }
  }

  static async revokeAllUserSessions(email) {
    const cleanEmail = (email || '').toLowerCase().trim();
    if (this.isMemoryMode()) {
      for (const [t, s] of memSessions.entries()) {
        if (s.email === cleanEmail) {
          memSessions.delete(t);
        }
      }
      return true;
    }

    try {
      const res = await docClient.send(new ScanCommand({
        TableName: TABLE_SESSIONS,
        FilterExpression: 'email = :e',
        ExpressionAttributeValues: { ':e': cleanEmail }
      }));
      if (res.Items) {
        for (const item of res.Items) {
          await this.deleteSession(item.token);
        }
      }
      return true;
    } catch (err) {
      console.error('Storage revokeAllUserSessions error:', err.message);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // OTPs
  // ---------------------------------------------------------------------------

  static async saveOtp(otpRecord) {
    const key = `${otpRecord.email}:${otpRecord.purpose}`;
    if (this.isMemoryMode()) {
      memOtps.set(key, { ...otpRecord });
      return true;
    }

    try {
      await docClient.send(new PutCommand({
        TableName: TABLE_OTPS,
        Item: {
          id: key,
          ...otpRecord
        }
      }));
      return true;
    } catch (err) {
      console.error('Storage saveOtp error:', err.message);
      throw err;
    }
  }

  static async getActiveOtp(email, purpose) {
    const key = `${(email || '').toLowerCase().trim()}:${purpose}`;
    if (this.isMemoryMode()) {
      const record = memOtps.get(key);
      return record ? { ...record } : null;
    }

    try {
      const res = await docClient.send(new GetCommand({
        TableName: TABLE_OTPS,
        Key: { id: key }
      }));
      return res.Item || null;
    } catch (err) {
      console.error('Storage getActiveOtp error:', err.message);
      throw err;
    }
  }

  static async updateOtp(email, purpose, updates) {
    const key = `${(email || '').toLowerCase().trim()}:${purpose}`;
    if (this.isMemoryMode()) {
      const r = memOtps.get(key);
      if (r) {
        Object.assign(r, updates);
      }
      return true;
    }

    try {
      await docClient.send(new UpdateCommand({
        TableName: TABLE_OTPS,
        Key: { id: key },
        UpdateExpression: 'SET isUsed = :u, failedAttempts = :f',
        ExpressionAttributeValues: {
          ':u': updates.isUsed !== undefined ? updates.isUsed : false,
          ':f': updates.failedAttempts !== undefined ? updates.failedAttempts : 0
        }
      }));
      return true;
    } catch (err) {
      console.error('Storage updateOtp error:', err.message);
      throw err;
    }
  }

  // ---------------------------------------------------------------------------
  // VERIFICATION TOKENS
  // ---------------------------------------------------------------------------

  static async saveVerificationToken(tokenRecord) {
    if (this.isMemoryMode()) {
      memTokens.set(tokenRecord.token, { ...tokenRecord });
      return true;
    }

    try {
      await docClient.send(new PutCommand({
        TableName: TABLE_TOKENS,
        Item: tokenRecord
      }));
      return true;
    } catch (err) {
      console.error('Storage saveVerificationToken error:', err.message);
      throw err;
    }
  }

  static async consumeVerificationToken(token, expectedPurpose, expectedEmail) {
    const cleanEmail = (expectedEmail || '').toLowerCase().trim();

    if (this.isMemoryMode()) {
      const t = memTokens.get(token);
      if (!t) return false;
      if (Date.now() > t.expiresAt) {
        memTokens.delete(token);
        return false;
      }
      if (t.purpose !== expectedPurpose || t.email !== cleanEmail) {
        return false;
      }
      memTokens.delete(token); // Single-use consumption
      return true;
    }

    try {
      const res = await docClient.send(new GetCommand({
        TableName: TABLE_TOKENS,
        Key: { token }
      }));
      const t = res.Item;
      if (!t) return false;
      if (Date.now() > t.expiresAt) {
        await docClient.send(new DeleteCommand({ TableName: TABLE_TOKENS, Key: { token } }));
        return false;
      }
      if (t.purpose !== expectedPurpose || t.email !== cleanEmail) {
        return false;
      }
      // Single-use: delete immediately
      await docClient.send(new DeleteCommand({ TableName: TABLE_TOKENS, Key: { token } }));
      return true;
    } catch (err) {
      console.error('Storage consumeVerificationToken error:', err.message);
      throw err;
    }
  }

  // ---------------------------------------------------------------------------
  // SONGS
  // ---------------------------------------------------------------------------

  static async saveSong(song) {
    if (this.isMemoryMode()) {
      memSongs.set(Number(song.id), { ...song });
      return true;
    }

    try {
      await docClient.send(new PutCommand({
        TableName: TABLE_SONGS,
        Item: {
          ...song,
          id: Number(song.id),
          updatedAt: new Date().toISOString()
        }
      }));
      return true;
    } catch (err) {
      console.error('Storage saveSong error:', err.message);
      throw err;
    }
  }

  static async getSong(songId) {
    const id = Number(songId);
    if (this.isMemoryMode()) {
      const s = memSongs.get(id);
      return s ? { ...s } : null;
    }

    try {
      const res = await docClient.send(new GetCommand({
        TableName: TABLE_SONGS,
        Key: { id }
      }));
      return res.Item || null;
    } catch (err) {
      console.error('Storage getSong error:', err.message);
      throw err;
    }
  }

  static async deleteSong(songId) {
    const id = Number(songId);
    if (this.isMemoryMode()) {
      memSongs.delete(id);
      return true;
    }

    try {
      await docClient.send(new DeleteCommand({
        TableName: TABLE_SONGS,
        Key: { id }
      }));
      return true;
    } catch (err) {
      console.error('Storage deleteSong error:', err.message);
      throw err;
    }
  }

  static async getSongsByUserId(userId) {
    if (this.isMemoryMode()) {
      const result = [];
      for (const s of memSongs.values()) {
        if (s.userId === userId) {
          result.push({ ...s });
        }
      }
      return result;
    }

    try {
      const res = await docClient.send(new ScanCommand({
        TableName: TABLE_SONGS,
        FilterExpression: 'userId = :uid',
        ExpressionAttributeValues: { ':uid': userId }
      }));
      return res.Items || [];
    } catch (err) {
      console.error('Storage getSongsByUserId error:', err.message);
      throw err;
    }
  }

  // ---------------------------------------------------------------------------
  // LIVE ROOMS (Real, Verified User Rooms Only — No Demos)
  // ---------------------------------------------------------------------------

  static isDemoRoom(room) {
    if (!room) return false;
    const code = (room.roomCode || '').toLowerCase().replace(/[^a-z0-9]/g, '');
    const id = (room.id || '').toLowerCase().replace(/[^a-z0-9]/g, '');
    const host = (room.hostName || '').toLowerCase();
    const title = (room.gameTitle || '').toLowerCase();

    const demoNumbers = ['5050', '4912', '1034', '8821', '2041', '5519', '3390', '1204', '7731', '9999'];
    for (const num of demoNumbers) {
      if (code.includes(num) || id.includes(num)) return true;
    }
    if (id.includes('seed') || code.includes('seed')) return true;

    const demoHostKeywords = [
      'kabir', 'aanya', 'annya', 'anya', 'rohan', 'priya', 'vikram',
      'brinda', 'simplychetana', 'chetana', 'pragati', 'alex vance',
      'cutie', 'deepak', 'pooja', 'game friends'
    ];
    for (const h of demoHostKeywords) {
      if (host.includes(h)) return true;
    }

    const demoTitleKeywords = [
      'game friends', 'bollywood', 'ludo friends & gift', 'chill lounge & songs',
      'late night jam', 'pro gamer arena', 'ludo masters club',
      'cyber neon arena', 'mega chalo party'
    ];
    for (const t of demoTitleKeywords) {
      if (title.includes(t)) return true;
    }

    return false;
  }

  static async purgeDemoRooms() {
    if (this.isMemoryMode()) {
      for (const [id, r] of memRooms.entries()) {
        if (this.isDemoRoom(r)) {
          memRooms.delete(id);
        }
      }
      return true;
    }

    try {
      const res = await docClient.send(new ScanCommand({
        TableName: TABLE_ROOMS
      }));
      const items = res.Items || [];
      for (const item of items) {
        if (this.isDemoRoom(item)) {
          await docClient.send(new DeleteCommand({
            TableName: TABLE_ROOMS,
            Key: { id: item.id }
          }));
        }
      }
      return true;
    } catch (err) {
      console.warn('Storage purgeDemoRooms warning:', err.message);
      return false;
    }
  }

  static async getRooms() {
    await this.purgeDemoRooms();

    if (this.isMemoryMode()) {
      return Array.from(memRooms.values()).filter(r => !this.isDemoRoom(r));
    }

    try {
      const res = await docClient.send(new ScanCommand({
        TableName: TABLE_ROOMS
      }));
      const list = res.Items || [];
      return list.filter(r => !this.isDemoRoom(r));
    } catch (err) {
      console.error('Storage getRooms error:', err.message);
      return Array.from(memRooms.values()).filter(r => !this.isDemoRoom(r));
    }
  }

  static async saveRoom(room) {
    if (!room || !room.id) return false;
    if (this.isDemoRoom(room)) return false; // reject demo rooms

    if (this.isMemoryMode()) {
      memRooms.set(room.id, { ...room, updatedAt: new Date().toISOString() });
      return true;
    }

    try {
      await docClient.send(new PutCommand({
        TableName: TABLE_ROOMS,
        Item: { ...room, updatedAt: new Date().toISOString() }
      }));
      return true;
    } catch (err) {
      console.error('Storage saveRoom error:', err.message);
      memRooms.set(room.id, { ...room, updatedAt: new Date().toISOString() });
      return true;
    }
  }

  static async deleteRoom(roomId) {
    if (!roomId) return false;
    if (this.isMemoryMode()) {
      let removed = memRooms.delete(roomId);
      for (const [id, r] of memRooms.entries()) {
        if (r.roomCode === roomId) {
          memRooms.delete(id);
          removed = true;
        }
      }
      return removed;
    }

    try {
      await docClient.send(new DeleteCommand({
        TableName: TABLE_ROOMS,
        Key: { id: roomId }
      }));
      return true;
    } catch (err) {
      console.error('Storage deleteRoom error:', err.message);
      memRooms.delete(roomId);
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // SOCIAL SEARCH & FOLLOW MANAGEMENT
  // ---------------------------------------------------------------------------

  static async searchUsers(query) {
    const raw = (query || '').trim().toLowerCase();
    if (!raw) return [];
    const cleanQ = raw.replace(/^@/, '');

    let allUsers = [];
    if (this.isMemoryMode()) {
      allUsers = Array.from(memUsers.values());
    } else {
      try {
        const res = await docClient.send(new ScanCommand({
          TableName: TABLE_USERS,
          Limit: 100
        }));
        allUsers = res.Items || [];
      } catch (err) {
        console.error('Storage searchUsers scan error:', err.message);
        allUsers = Array.from(memUsers.values());
      }
    }

    const matched = [];
    for (const u of allUsers) {
      const email = (u.email || '').toLowerCase();
      const name = (u.name || '').toLowerCase();
      const tag = (u.gamerTag || u.tag || '').toLowerCase().replace(/^@/, '');
      const secId = (u.securityId || u.userId || u.id || '').toLowerCase();

      if (
        tag === cleanQ ||
        tag.includes(cleanQ) ||
        secId === cleanQ ||
        secId.includes(cleanQ) ||
        email === cleanQ ||
        email.startsWith(cleanQ) ||
        name.includes(cleanQ)
      ) {
        const finalId = u.securityId || u.userId || u.id || `01${Math.floor(100000 + Math.random() * 900000)}`;
        matched.push({
          id: finalId,
          securityId: finalId,
          name: u.name || 'Player',
          gamerTag: u.gamerTag || u.tag || `@${(u.name || 'player').toLowerCase().replace(/\s+/g, '_')}`,
          email: u.email,
          level: u.level || 1,
          coins: u.coins || 500,
          totalWins: u.totalWins || u.trophies || 0,
          profilePhoto: u.profilePhoto || null,
          followers: u.followers || [],
          following: u.following || [],
          followersCount: Array.isArray(u.followers) ? u.followers.length : (u.followersCount ?? 0),
          followingCount: Array.isArray(u.following) ? u.following.length : (u.followingCount ?? 0),
          visitorsCount: u.visitorsCount ?? 15
        });
      }
    }
    return matched;
  }

  static async followUser({ followerEmail, followerName, targetGamerTagOrId, follow = true }) {
    if (!followerEmail || !targetGamerTagOrId) {
      return { success: false, error: 'followerEmail and targetGamerTagOrId required' };
    }

    const cleanFollower = followerEmail.toLowerCase().trim();
    const cleanTarget = targetGamerTagOrId.toLowerCase().trim().replace(/^@/, '');

    // 1. Get follower user
    let followerUser = await this.getUserByEmail(cleanFollower);
    // 2. Find target user
    let targetUser = null;
    let allUsers = [];

    if (this.isMemoryMode()) {
      allUsers = Array.from(memUsers.values());
    } else {
      try {
        const res = await docClient.send(new ScanCommand({ TableName: TABLE_USERS, Limit: 100 }));
        allUsers = res.Items || [];
      } catch (err) {
        allUsers = Array.from(memUsers.values());
      }
    }

    for (const u of allUsers) {
      const tag = (u.gamerTag || '').toLowerCase().replace(/^@/, '');
      const secId = (u.securityId || u.id || '').toLowerCase();
      const email = (u.email || '').toLowerCase();
      if (tag === cleanTarget || secId === cleanTarget || email === cleanTarget) {
        targetUser = u;
        break;
      }
    }

    if (!targetUser) {
      // Create synthetic response for demo or offline target
      return {
        success: true,
        isFollowing: follow,
        targetName: targetGamerTagOrId,
        followersCount: follow ? 1 : 0
      };
    }

    // Update target's followers list
    let targetFollowers = Array.isArray(targetUser.followers) ? [...targetUser.followers] : [];
    if (follow) {
      if (!targetFollowers.includes(cleanFollower)) targetFollowers.push(cleanFollower);
    } else {
      targetFollowers = targetFollowers.filter(e => e !== cleanFollower);
    }
    targetUser.followers = targetFollowers;
    targetUser.followersCount = targetFollowers.length;

    // Update follower's following list if follower exists
    if (followerUser) {
      let followerFollowing = Array.isArray(followerUser.following) ? [...followerUser.following] : [];
      const targetIdent = targetUser.gamerTag || targetUser.email;
      if (follow) {
        if (!followerFollowing.includes(targetIdent)) followerFollowing.push(targetIdent);
      } else {
        followerFollowing = followerFollowing.filter(e => e !== targetIdent);
      }
      followerUser.following = followerFollowing;
      followerUser.followingCount = followerFollowing.length;
    }

    if (this.isMemoryMode()) {
      memUsers.set(targetUser.email.toLowerCase(), targetUser);
      if (followerUser) memUsers.set(followerUser.email.toLowerCase(), followerUser);
    } else {
      try {
        await docClient.send(new PutCommand({
          TableName: TABLE_USERS,
          Item: targetUser
        }));
        if (followerUser) {
          await docClient.send(new PutCommand({
            TableName: TABLE_USERS,
            Item: followerUser
          }));
        }
      } catch (err) {
        console.warn('Storage followUser DDB write warning:', err.message);
      }
    }

    return {
      success: true,
      isFollowing: follow,
      targetName: targetUser.name,
      targetTag: targetUser.gamerTag,
      followersCount: targetFollowers.length,
      followingCount: followerUser ? (followerUser.following || []).length : 0
    };
  }
}

module.exports = Storage;
