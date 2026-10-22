// =============================================================================
// Play Friends - Authoritative Production AWS Lambda Handler (Node.js 20.x)
// Table: PlayFriends_Users (Primary Key: Email [String])
// Region: ap-southeast-2 (Sydney)
// Single-Table Architecture: Users, Rooms, Seats, Songs, & Direct Messages
// Zero external npm dependencies: uses built-in AWS SDK v3 in Lambda runtime
// =============================================================================

import { DynamoDBClient, DescribeTableCommand } from "@aws-sdk/client-dynamodb";
import {
    DynamoDBDocumentClient,
    PutCommand,
    ScanCommand,
    GetCommand,
    DeleteCommand,
    UpdateCommand
} from "@aws-sdk/lib-dynamodb";
import crypto from "crypto";

const client = new DynamoDBClient({
    region: process.env.AWS_REGION || "ap-southeast-2"
});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_USERS = process.env.TABLE_NAME || "PlayFriends_Users";

let cachedKeySchema = null;
async function getTableKeySchema() {
    if (cachedKeySchema && cachedKeySchema.length > 0) return cachedKeySchema;
    try {
        const info = await client.send(new DescribeTableCommand({ TableName: TABLE_USERS }));
        cachedKeySchema = info.Table?.KeySchema || [];
        return cachedKeySchema;
    } catch (e) {
        return [{ AttributeName: "Email", KeyType: "HASH" }];
    }
}

function buildKey(item, keySchema) {
    const key = {};
    for (const k of (keySchema || [])) {
        const name = k.AttributeName;
        key[name] = item[name] ?? item[name.toLowerCase()] ?? item[name.toUpperCase()];
    }
    return Object.keys(key).length > 0 ? key : { Email: item.Email || item.email };
}

function makeResponse(statusCode, body) {
    return {
        statusCode,
        headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization,X-Api-Key",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS"
        },
        body: JSON.stringify(body)
    };
}

function verifyPassword(inputPassword, storedPassword, storedHash) {
    if (!inputPassword) return false;
    if (storedPassword && storedPassword === inputPassword) return true;
    if (storedHash && storedHash === inputPassword) return true;
    if (storedHash && storedHash.includes(":")) {
        const parts = storedHash.split(":");
        if (parts.length === 2) {
            const [salt, key] = parts;
            const derived = crypto.scryptSync(inputPassword, salt, 64).toString("hex");
            if (crypto.timingSafeEqual(Buffer.from(key, "hex"), Buffer.from(derived, "hex"))) {
                return true;
            }
        }
    }
    return false;
}

export const handler = async (event) => {
    const httpMethod = (event.requestContext?.http?.method || event.httpMethod || "").toUpperCase();
    if (httpMethod === "OPTIONS") {
        return makeResponse(204, {});
    }

    let body = {};
    if (event.body) {
        try {
            body = typeof event.body === "string" ? JSON.parse(event.body) : event.body;
        } catch (e) {
            return makeResponse(400, { success: false, error: "Invalid JSON request payload." });
        }
    }

    const action = body.action || "ping";

    try {
        // ---------------------------------------------------------------------
        // 1. HEALTH / PING
        // ---------------------------------------------------------------------
        if (action === "ping") {
            return makeResponse(200, { status: "ok", message: "Play Friends AWS backend online" });
        }

        // ---------------------------------------------------------------------
        // 2. CHECK USER UNIQUENESS (EMAIL & MOBILE)
        // ---------------------------------------------------------------------
        if (action === "checkUser") {
            const cleanEmail = (body.email || "").toLowerCase().trim();
            const cleanMobile = (body.mobile || body.phoneNumber || "").trim().replace(/\D/g, "");

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            for (const item of (scanResult.Items || [])) {
                if (item.entityType === "ROOM" || item.entityType === "MESSAGE" || item.entityType === "SONG") continue;

                const itemEmail = (item.email || item.Email || "").toLowerCase().trim();
                const itemMobile = (item.phoneNumber || item.mobile || "").trim().replace(/\D/g, "");

                if (cleanEmail && itemEmail === cleanEmail) {
                    return makeResponse(200, {
                        exists: true,
                        field: "email",
                        message: "This email is already registered. Please sign in or use another email."
                    });
                }
                if (cleanMobile && itemMobile.length >= 10 && (itemMobile === cleanMobile || itemMobile.endsWith(cleanMobile) || cleanMobile.endsWith(itemMobile))) {
                    return makeResponse(200, {
                        exists: true,
                        field: "mobile",
                        message: "This mobile number is already in use. Please enter a different number."
                    });
                }
            }

            return makeResponse(200, { exists: false });
        }

        // ---------------------------------------------------------------------
        // 3. REGISTER USER ACCOUNT
        // ---------------------------------------------------------------------
        if (action === "register") {
            const cleanEmail = (body.email || "").toLowerCase().trim();
            const cleanMobile = (body.mobile || body.phoneNumber || "").trim().replace(/\D/g, "");

            if (!cleanEmail) {
                return makeResponse(400, { success: false, error: "Email is required for registration." });
            }

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            for (const item of (scanResult.Items || [])) {
                if (item.entityType === "ROOM" || item.entityType === "MESSAGE" || item.entityType === "SONG") continue;

                const itemEmail = (item.email || item.Email || "").toLowerCase().trim();
                const itemMobile = (item.phoneNumber || item.mobile || "").trim().replace(/\D/g, "");

                if (itemEmail === cleanEmail) {
                    return makeResponse(409, {
                        success: false,
                        field: "email",
                        error: "An account with this email already exists."
                    });
                }
                if (cleanMobile && itemMobile.length >= 10 && (itemMobile === cleanMobile || itemMobile.endsWith(cleanMobile) || cleanMobile.endsWith(itemMobile))) {
                    return makeResponse(409, {
                        success: false,
                        field: "mobile",
                        error: "This phone number is already registered with another account."
                    });
                }
            }

            const userId = body.id || body.userId || `u_${Date.now()}`;
            const gamerTag = body.gamerTag || body.tag || `@user_${userId.substring(userId.length - 4)}`;
            const password = body.password || "";
            const salt = crypto.randomBytes(16).toString("hex");
            const passwordHash = password ? `${salt}:${crypto.scryptSync(password, salt, 64).toString("hex")}` : "";

            const newUser = {
                Email: cleanEmail,
                email: cleanEmail,
                entityType: "USER",
                id: userId,
                userId: userId,
                securityId: userId,
                name: body.name || "New Player",
                gamerTag: gamerTag,
                tag: gamerTag,
                phoneNumber: body.phoneNumber || body.mobile || "",
                password: password,
                passwordHash: passwordHash,
                level: 1,
                coins: 500,
                trophies: 0,
                profilePhoto: body.profilePhoto || null,
                followers: [],
                following: [],
                followersCount: 0,
                followingCount: 0,
                visitorsCount: 0,
                notifications: [],
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: newUser
            }));

            return makeResponse(201, {
                success: true,
                message: "User registered successfully",
                user: newUser
            });
        }

        // ---------------------------------------------------------------------
        // 4. LOGIN WITH CREDENTIALS
        // ---------------------------------------------------------------------
        if (action === "login") {
            const identifier = (body.identifier || body.email || "").toLowerCase().trim();
            const password = body.password || "";

            if (!identifier) {
                return makeResponse(400, { success: false, error: "Email, Gamer Tag, or Security ID is required." });
            }

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            let matchedUser = null;
            const cleanClean = identifier.replace(/^@/, "");

            for (const item of (scanResult.Items || [])) {
                if (item.entityType === "ROOM" || item.entityType === "MESSAGE" || item.entityType === "SONG") continue;

                const itemEmail = (item.email || item.Email || "").toLowerCase().trim();
                const itemTag = (item.gamerTag || item.tag || "").toLowerCase().trim().replace(/^@/, "");
                const itemId = (item.userId || item.id || item.securityId || "").toLowerCase().trim();
                const itemMobile = (item.phoneNumber || item.mobile || "").trim().replace(/\D/g, "");

                if (itemEmail === identifier || itemTag === cleanClean || itemId === identifier || (identifier.length >= 10 && itemMobile === identifier)) {
                    matchedUser = item;
                    break;
                }
            }

            if (!matchedUser) {
                return makeResponse(404, { success: false, error: "No player found with those credentials." });
            }

            if (password) {
                const storedPassword = matchedUser.password || "";
                const storedHash = matchedUser.passwordHash || "";
                const isValid = verifyPassword(password, storedPassword, storedHash);

                if (!isValid) {
                    return makeResponse(401, { success: false, error: "Incorrect password. Please try again." });
                }
            }

            return makeResponse(200, {
                success: true,
                message: "Login successful",
                user: matchedUser
            });
        }

        // ---------------------------------------------------------------------
        // 5. VALIDATE SESSION
        // ---------------------------------------------------------------------
        if (action === "validateSession") {
            const email = (body.email || "").toLowerCase().trim();
            if (!email) return makeResponse(400, { valid: false, error: "Email required" });

            const getResult = await docClient.send(new GetCommand({
                TableName: TABLE_USERS,
                Key: { Email: email }
            }));

            return makeResponse(200, { valid: !!getResult.Item, user: getResult.Item || null });
        }

        // ---------------------------------------------------------------------
        // 6. LOGOUT
        // ---------------------------------------------------------------------
        if (action === "logout") {
            return makeResponse(200, { success: true, message: "Logged out successfully" });
        }

        // ---------------------------------------------------------------------
        // 7. RESET PASSWORD
        // ---------------------------------------------------------------------
        if (action === "resetPassword") {
            const email = (body.email || "").toLowerCase().trim();
            const newPassword = body.newPassword || "";

            if (!email || !newPassword) {
                return makeResponse(400, { success: false, error: "Email and newPassword are required." });
            }

            const getResult = await docClient.send(new GetCommand({
                TableName: TABLE_USERS,
                Key: { Email: email }
            }));

            if (!getResult.Item) {
                return makeResponse(404, { success: false, error: "Account not found for email: " + email });
            }

            const user = getResult.Item;
            const salt = crypto.randomBytes(16).toString("hex");
            user.password = newPassword;
            user.passwordHash = `${salt}:${crypto.scryptSync(newPassword, salt, 64).toString("hex")}`;
            user.updatedAt = new Date().toISOString();
            user.Email = user.Email || user.email;

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: user
            }));

            return makeResponse(200, { success: true, message: "Password updated successfully" });
        }

        // ---------------------------------------------------------------------
        // 8. LIST USERS / REGISTERED PLAYERS DIRECTORY
        // ---------------------------------------------------------------------
        if (action === "listUsers" || action === "getAllUsers") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const users = (scanResult.Items || [])
                .filter(u => !u.entityType || u.entityType === "USER")
                .filter(u => u.Email && !u.Email.startsWith("ROOM#") && !u.Email.startsWith("MSG#") && !u.Email.startsWith("SONG#"))
                .map(u => ({
                    id: u.userId || u.id,
                    userId: u.userId || u.id,
                    securityId: u.securityId || u.userId || u.id,
                    name: u.name || "Player",
                    gamerTag: u.tag || u.gamerTag || "@player",
                    email: u.email || u.Email,
                    phoneNumber: u.phoneNumber || "",
                    level: u.level || 1,
                    coins: u.coins || 500,
                    trophies: u.trophies || u.totalWins || 0,
                    profilePhoto: u.profilePhoto || null,
                    followersCount: Array.isArray(u.followers) ? u.followers.length : (u.followersCount || 0),
                    followingCount: Array.isArray(u.following) ? u.following.length : (u.followingCount || 0),
                    visitorsCount: (typeof u.visitorsCount === 'number') ? u.visitorsCount : 0,
                    createdAt: u.createdAt || new Date().toISOString()
                }));

            return makeResponse(200, users);
        }

        // ---------------------------------------------------------------------
        // 9. SEARCH USERS
        // ---------------------------------------------------------------------
        if (action === "searchUsers") {
            const query = (body.query || "").toLowerCase().trim().replace(/^@/, "");
            if (!query) return makeResponse(200, []);

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const matches = (scanResult.Items || [])
                .filter(u => !u.entityType || u.entityType === "USER")
                .filter(u => u.Email && !u.Email.startsWith("ROOM#") && !u.Email.startsWith("MSG#") && !u.Email.startsWith("SONG#"))
                .filter(u => {
                    const id = (u.userId || u.id || "").toLowerCase();
                    const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                    const name = (u.name || "").toLowerCase();
                    const email = (u.email || u.Email || "").toLowerCase();
                    return id.includes(query) || tag.includes(query) || name.includes(query) || email.includes(query);
                })
                .map(u => ({
                    id: u.userId || u.id,
                    userId: u.userId || u.id,
                    securityId: u.securityId || u.userId || u.id,
                    name: u.name,
                    gamerTag: u.tag || u.gamerTag,
                    email: u.email || u.Email,
                    level: u.level || 1,
                    coins: u.coins || 500,
                    totalWins: u.trophies || u.totalWins || 0,
                    profilePhoto: u.profilePhoto || null,
                    followersCount: Array.isArray(u.followers) ? u.followers.length : (u.followersCount || 0),
                    followingCount: Array.isArray(u.following) ? u.following.length : (u.followingCount || 0),
                    visitorsCount: (typeof u.visitorsCount === 'number') ? u.visitorsCount : 0
                }));

            return makeResponse(200, matches);
        }

        // ---------------------------------------------------------------------
        // 10. SOCIAL GRAPH: FOLLOW / UNFOLLOW USER
        // ---------------------------------------------------------------------
        if (action === "followUser") {
            const followerId = (body.followerId || body.followerEmail || "").toLowerCase().trim();
            const targetId = (body.targetId || body.targetGamerTagOrId || "").toLowerCase().trim().replace(/^@/, "");
            const follow = body.follow !== false;

            if (!followerId || !targetId) {
                return makeResponse(400, { success: false, error: "followerId and targetId are required." });
            }

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const allUsers = (scanResult.Items || []).filter(u => !u.entityType || u.entityType === "USER");
            let followerUser = null;
            let targetUser = null;

            for (const item of allUsers) {
                const itemEmail = (item.email || item.Email || "").toLowerCase();
                const itemTag = (item.tag || item.gamerTag || "").toLowerCase().replace(/^@/, "");
                const itemId = (item.userId || item.id || "").toLowerCase();
                const itemName = (item.name || "").toLowerCase().trim();

                if (!followerUser && (itemEmail === followerId || itemId === followerId || itemTag === followerId.replace(/^@/, "") || itemName === followerId)) {
                    followerUser = item;
                }
                if (!targetUser && (itemEmail === targetId || itemId === targetId || itemTag === targetId || itemName === targetId)) {
                    targetUser = item;
                }
            }

            if (!targetUser) {
                return makeResponse(200, {
                    success: true,
                    isFollowing: follow,
                    followersCount: follow ? 1 : 0
                });
            }

            // Update Target's followers list
            const targetFollowers = Array.isArray(targetUser.followers) ? [...targetUser.followers] : [];
            const followerKey = followerUser ? (followerUser.userId || followerUser.email || followerUser.Email) : followerId;

            if (follow) {
                if (!targetFollowers.includes(followerKey)) {
                    targetFollowers.push(followerKey);
                }
                // Push notification to targetUser
                const notifs = Array.isArray(targetUser.notifications) ? [...targetUser.notifications] : [];
                notifs.unshift({
                    id: `notif_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
                    type: "follow",
                    title: "New Follower! 👤",
                    message: `${followerUser ? followerUser.name : (body.followerName || followerId)} started following you!`,
                    senderName: followerUser ? followerUser.name : (body.followerName || followerId),
                    senderTag: followerUser ? (followerUser.tag || followerUser.gamerTag) : "",
                    senderId: followerUser ? (followerUser.userId || followerUser.id) : followerId,
                    senderPhoto: followerUser ? followerUser.profilePhoto : null,
                    createdAt: new Date().toISOString(),
                    isRead: false
                });
                targetUser.notifications = notifs.slice(0, 50);
            } else {
                const idx = targetFollowers.indexOf(followerKey);
                if (idx !== -1) targetFollowers.splice(idx, 1);
            }

            targetUser.followers = targetFollowers;
            targetUser.followersCount = targetFollowers.length;
            targetUser.Email = targetUser.Email || targetUser.email;
            targetUser.updatedAt = new Date().toISOString();

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: targetUser
            }));

            // Update Follower's following list
            let followingCount = 0;
            if (followerUser) {
                const followerFollowing = Array.isArray(followerUser.following) ? [...followerUser.following] : [];
                const targetKey = targetUser.userId || targetUser.email || targetUser.Email;

                if (follow) {
                    if (!followerFollowing.includes(targetKey)) {
                        followerFollowing.push(targetKey);
                    }
                } else {
                    const idx = followerFollowing.indexOf(targetKey);
                    if (idx !== -1) followerFollowing.splice(idx, 1);
                }

                followerUser.following = followerFollowing;
                followerUser.followingCount = followerFollowing.length;
                followerUser.Email = followerUser.Email || followerUser.email;
                followerUser.updatedAt = new Date().toISOString();
                followingCount = followerFollowing.length;

                await docClient.send(new PutCommand({
                    TableName: TABLE_USERS,
                    Item: followerUser
                }));
            }

            return makeResponse(200, {
                success: true,
                isFollowing: follow,
                targetName: targetUser.name,
                targetTag: targetUser.tag || targetUser.gamerTag,
                followersCount: targetFollowers.length,
                followingCount: followingCount
            });
        }

        // ---------------------------------------------------------------------
        // 11. SOCIAL GRAPH: GET FOLLOWERS & FOLLOWING
        // ---------------------------------------------------------------------
        if (action === "getFollowers" || action === "getFollowing") {
            const rawId = (body.userId || body.email || body.tag || "").toLowerCase().trim().replace(/^@/, "");

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const items = (scanResult.Items || []).filter(u => !u.entityType || u.entityType === "USER");
            const target = items.find(u => {
                const email = (u.email || u.Email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const name = (u.name || "").toLowerCase().trim();
                return email === rawId || id === rawId || tag === rawId || name === rawId;
            });

            if (!target) {
                return makeResponse(200, { success: true, list: [], count: 0 });
            }

            const keyList = action === "getFollowers" ? (target.followers || []) : (target.following || []);
            const resultList = [];

            for (const key of keyList) {
                const kLower = (key || "").toLowerCase();
                const match = items.find(u => {
                    const email = (u.email || u.Email || "").toLowerCase();
                    const id = (u.userId || u.id || "").toLowerCase();
                    const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                    const name = (u.name || "").toLowerCase().trim();
                    return email === kLower || id === kLower || tag === kLower || name === kLower;
                });
                if (match) {
                    resultList.push({
                        id: match.userId || match.id,
                        name: match.name,
                        tag: match.tag || match.gamerTag,
                        profilePhoto: match.profilePhoto || null,
                        level: match.level || 1
                    });
                } else {
                    resultList.push({ id: key, name: "Player", tag: "@player", profilePhoto: null, level: 1 });
                }
            }

            return makeResponse(200, { success: true, list: resultList, count: resultList.length });
        }

        // ---------------------------------------------------------------------
        // 12. SOCIAL GRAPH: GET FOLLOW STATUS & MUTUAL FRIENDSHIP
        // ---------------------------------------------------------------------
        if (action === "getFollowStatus") {
            const currentId = (body.currentUserId || body.followerId || "").toLowerCase().trim().replace(/^@/, "");
            const targetId = (body.targetUserId || body.targetId || "").toLowerCase().trim().replace(/^@/, "");

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const items = (scanResult.Items || []).filter(u => !u.entityType || u.entityType === "USER");
            const currentUser = items.find(u => {
                const email = (u.email || u.Email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const name = (u.name || "").toLowerCase().trim();
                return email === currentId || id === currentId || tag === currentId || name === currentId;
            });

            const targetUser = items.find(u => {
                const email = (u.email || u.Email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const name = (u.name || "").toLowerCase().trim();
                return email === targetId || id === targetId || tag === targetId || name === targetId;
            });

            let isFollowing = false;
            let isFollowedBy = false;

            if (currentUser && targetUser) {
                const cKeys = [
                    (currentUser.userId || "").toLowerCase(),
                    (currentUser.id || "").toLowerCase(),
                    (currentUser.email || currentUser.Email || "").toLowerCase(),
                    (currentUser.name || "").toLowerCase().trim(),
                    (currentUser.tag || currentUser.gamerTag || "").toLowerCase().replace(/^@/, "")
                ].filter(Boolean);

                const tKeys = [
                    (targetUser.userId || "").toLowerCase(),
                    (targetUser.id || "").toLowerCase(),
                    (targetUser.email || targetUser.Email || "").toLowerCase(),
                    (targetUser.name || "").toLowerCase().trim(),
                    (targetUser.tag || targetUser.gamerTag || "").toLowerCase().replace(/^@/, "")
                ].filter(Boolean);

                const cFollowing = (currentUser.following || []).map(x => (x || "").toLowerCase().replace(/^@/, ""));
                const tFollowing = (targetUser.following || []).map(x => (x || "").toLowerCase().replace(/^@/, ""));
                const cFollowers = (currentUser.followers || []).map(x => (x || "").toLowerCase().replace(/^@/, ""));
                const tFollowers = (targetUser.followers || []).map(x => (x || "").toLowerCase().replace(/^@/, ""));

                isFollowing = tKeys.some(tk => cFollowing.includes(tk) || tFollowers.includes(tk));
                isFollowedBy = cKeys.some(ck => tFollowing.includes(ck) || cFollowers.includes(ck));
            }

            return makeResponse(200, {
                success: true,
                isFollowing,
                isFollowedBy,
                isMutual: isFollowing && isFollowedBy
            });
        }

        // ---------------------------------------------------------------------
        // 12B. NOTIFICATIONS: GET & CLEAR
        // ---------------------------------------------------------------------
        if (action === "getNotifications") {
            const rawId = (body.userId || body.email || body.tag || "").toLowerCase().trim().replace(/^@/, "");
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));
            const items = (scanResult.Items || []).filter(u => !u.entityType || u.entityType === "USER");
            const target = items.find(u => {
                const email = (u.email || u.Email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const name = (u.name || "").toLowerCase().trim();
                return email === rawId || id === rawId || tag === rawId || name === rawId;
            });

            return makeResponse(200, {
                success: true,
                notifications: (target && Array.isArray(target.notifications)) ? target.notifications : []
            });
        }

        if (action === "markNotificationsRead" || action === "clearNotifications") {
            const rawId = (body.userId || body.email || body.tag || "").toLowerCase().trim().replace(/^@/, "");
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));
            const items = (scanResult.Items || []).filter(u => !u.entityType || u.entityType === "USER");
            const target = items.find(u => {
                const email = (u.email || u.Email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const name = (u.name || "").toLowerCase().trim();
                return email === rawId || id === rawId || tag === rawId || name === rawId;
            });

            if (target) {
                target.notifications = [];
                target.Email = target.Email || target.email;
                target.updatedAt = new Date().toISOString();
                await docClient.send(new PutCommand({
                    TableName: TABLE_USERS,
                    Item: target
                }));
            }
            return makeResponse(200, { success: true });
        }

        // ---------------------------------------------------------------------
        // 12C. GIFTING: DEDUCT SENDER, RECIPIENT COIN INCREASE & NOTIFICATION
        // ---------------------------------------------------------------------
        if (action === "sendGift") {
            const senderId = (body.senderId || body.senderEmail || "").toLowerCase().trim();
            const recipientId = (body.recipientId || body.recipientName || body.recipientTag || "").toLowerCase().trim().replace(/^@/, "");
            const coins = parseInt(body.coins || body.cost || 0, 10);
            const giftName = body.giftName || "Gift";
            const giftIcon = body.giftIcon || "🎁";

            if (coins <= 0) {
                return makeResponse(400, { success: false, error: "coins must be greater than 0." });
            }

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));
            const items = (scanResult.Items || []).filter(u => !u.entityType || u.entityType === "USER");

            let senderUser = items.find(u => {
                const email = (u.email || u.Email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const name = (u.name || "").toLowerCase().trim();
                return email === senderId || id === senderId || tag === senderId || name === senderId;
            });

            let recipientUser = items.find(u => {
                const email = (u.email || u.Email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const name = (u.name || "").toLowerCase().trim();
                return email === recipientId || id === recipientId || tag === recipientId || name === recipientId;
            });

            if (recipientUser) {
                recipientUser.coins = (parseInt(recipientUser.coins || 0, 10)) + coins;
                const notifs = Array.isArray(recipientUser.notifications) ? [...recipientUser.notifications] : [];
                notifs.unshift({
                    id: `notif_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
                    type: "gift",
                    title: "Gift Received! 🎁",
                    message: `${senderUser ? senderUser.name : (body.senderName || "A friend")} sent you ${giftIcon} ${giftName} (+${coins} coins)!`,
                    coins: coins,
                    senderName: senderUser ? senderUser.name : (body.senderName || "A friend"),
                    giftName: giftName,
                    giftIcon: giftIcon,
                    createdAt: new Date().toISOString(),
                    isRead: false
                });
                recipientUser.notifications = notifs.slice(0, 50);
                recipientUser.Email = recipientUser.Email || recipientUser.email;
                recipientUser.updatedAt = new Date().toISOString();
                await docClient.send(new PutCommand({
                    TableName: TABLE_USERS,
                    Item: recipientUser
                }));
            }

            if (senderUser) {
                senderUser.coins = Math.max(0, (parseInt(senderUser.coins || 0, 10)) - coins);
                senderUser.Email = senderUser.Email || senderUser.email;
                senderUser.updatedAt = new Date().toISOString();
                await docClient.send(new PutCommand({
                    TableName: TABLE_USERS,
                    Item: senderUser
                }));
            }

            return makeResponse(200, {
                success: true,
                coinsAwarded: coins,
                senderCoins: senderUser ? senderUser.coins : undefined,
                recipientCoins: recipientUser ? recipientUser.coins : undefined
            });
        }

        // ---------------------------------------------------------------------
        // 13. ROOM MANAGEMENT: GET ROOMS, CREATE ROOM, DELETE ROOM
        // ---------------------------------------------------------------------
        if (action === "getRooms") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            // Filter out deleted rooms and legacy demo rooms
            const rooms = (scanResult.Items || []).filter(r => {
                if (r.entityType !== "ROOM" && !(r.Email && r.Email.startsWith("ROOM#"))) return false;
                if (r.isDeleted === true) return false;

                const id = (r.id || "").toString().toLowerCase();
                const code = (r.roomCode || "").toString().toLowerCase();
                const host = (r.hostName || "").toString().toLowerCase();
                return id !== "5050" && id !== "pf4912" && id !== "pf1034" &&
                       code !== "5050" && code !== "pf4912" && code !== "pf1034" &&
                       !host.includes("annya") && !host.includes("rohan") && !host.includes("game friends");
            });

            return makeResponse(200, rooms);
        }

        if (action === "createRoom") {
            const room = body.room || body;
            const roomId = room.id || `r_${Date.now()}`;
            const hostUser = body.user || {};

            const hostMember = {
                userId: hostUser.id || hostUser.userId || room.hostId || "host_01",
                name: room.hostName || hostUser.name || "Host Player",
                gamerTag: hostUser.tag || hostUser.gamerTag || "@host",
                profilePhoto: room.hostPhoto || hostUser.profilePhoto || null,
                role: "host",
                joinedAt: new Date().toISOString()
            };

            const defaultSeats = [
                {
                    seatIndex: 1,
                    userId: hostMember.userId,
                    userName: hostMember.name,
                    userPhoto: hostMember.profilePhoto,
                    userColor: 0xFF8B5CF6,
                    level: hostUser.level || 1,
                    isHost: true,
                    isMuted: false,
                    isSpeaking: true
                },
                null, null, null, null, null, null, null
            ];

            const item = {
                ...room,
                Email: `ROOM#${roomId}`,
                entityType: "ROOM",
                id: roomId,
                roomCode: room.roomCode || `PF-${Math.floor(1000 + Math.random() * 9000)}`,
                gameTitle: room.gameTitle || `${hostMember.name}'s Room`,
                hostName: hostMember.name,
                hostPhoto: hostMember.profilePhoto,
                members: [hostMember],
                seats: room.seats || defaultSeats,
                currentSong: null,
                currentPlayers: 1,
                maxPlayers: room.maxPlayers || 100,
                isDeleted: false,
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: item
            }));

            return makeResponse(201, { success: true, room: item });
        }

        if (action === "deleteRoom") {
            const roomId = (body.roomId || body.id || body.roomCode || "").toString();
            if (roomId) {
                const cleanKey = roomId.startsWith("ROOM#") ? roomId : `ROOM#${roomId}`;
                try {
                    await docClient.send(new DeleteCommand({
                        TableName: TABLE_USERS,
                        Key: { Email: cleanKey }
                    }));
                } catch (e) {}

                try {
                    const scanResult = await docClient.send(new ScanCommand({
                        TableName: TABLE_USERS,
                        Limit: 150
                    }));
                    const cleanCode = roomId.replace(/^PF-/i, "").toLowerCase();
                    for (const r of (scanResult.Items || [])) {
                        if (r.entityType === "ROOM" || (r.Email && r.Email.startsWith("ROOM#"))) {
                            const rId = (r.id || "").toString().toLowerCase();
                            const rCode = (r.roomCode || "").toString().replace(/^PF-/i, "").toLowerCase();
                            if (rId === roomId.toLowerCase() || rCode === cleanCode || r.Email === cleanKey) {
                                try {
                                    await docClient.send(new DeleteCommand({
                                        TableName: TABLE_USERS,
                                        Key: { Email: r.Email }
                                    }));
                                } catch (err) {}
                            }
                        }
                    }
                } catch (err) {}
            }
            return makeResponse(200, { success: true, message: "Room deleted successfully" });
        }

        // ---------------------------------------------------------------------
        // 13B. ROOM MODERATION & PERSISTENT CHAT: KICK USER, SEND/CLEAR CHAT
        // ---------------------------------------------------------------------
        if (action === "kickUser") {
            const rawId = (body.roomId || body.id || body.roomCode || "").toString();
            const targetId = (body.targetUserId || body.targetUserName || "").toString().toLowerCase().trim();
            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;

            let roomItem = null;
            try {
                const getResult = await docClient.send(new GetCommand({
                    TableName: TABLE_USERS,
                    Key: { Email: cleanKey }
                }));
                roomItem = getResult.Item;
            } catch (e) {}

            if (!roomItem) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_USERS,
                    Limit: 150
                }));
                const cleanCode = rawId.replace(/^PF-/i, "").toLowerCase();
                roomItem = (scanResult.Items || []).find(r => {
                    const rId = (r.id || "").toString().toLowerCase();
                    const rCode = (r.roomCode || "").toString().replace(/^PF-/i, "").toLowerCase();
                    return rId === rawId.toLowerCase() || rCode === cleanCode;
                });
            }

            if (roomItem) {
                const kicked = Array.isArray(roomItem.kickedUsers) ? [...roomItem.kickedUsers] : [];
                if (!kicked.includes(targetId)) kicked.push(targetId);
                roomItem.kickedUsers = kicked;

                // Remove from members
                roomItem.members = (roomItem.members || []).filter(m => {
                    const mId = (m.userId || m.id || "").toString().toLowerCase();
                    const mName = (m.name || "").toString().toLowerCase();
                    return mId !== targetId && mName !== targetId;
                });

                // Vacate seat
                roomItem.seats = (roomItem.seats || []).map(s => {
                    if (!s) return null;
                    const sId = (s.userId || s.id || "").toString().toLowerCase();
                    const sName = (s.userName || s.name || "").toString().toLowerCase();
                    if (sId === targetId || sName === targetId) return null;
                    return s;
                });

                roomItem.Email = roomItem.Email || cleanKey;
                roomItem.updatedAt = new Date().toISOString();
                await docClient.send(new PutCommand({
                    TableName: TABLE_USERS,
                    Item: roomItem
                }));
                return makeResponse(200, { success: true, kickedUsers: roomItem.kickedUsers });
            }
            return makeResponse(404, { success: false, error: "Room not found" });
        }

        if (action === "sendRoomMessage") {
            const rawId = (body.roomId || body.id || body.roomCode || "").toString();
            const message = body.message;
            if (!rawId || !message) {
                return makeResponse(400, { success: false, error: "roomId and message are required" });
            }

            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;
            let roomItem = null;
            try {
                const getResult = await docClient.send(new GetCommand({
                    TableName: TABLE_USERS,
                    Key: { Email: cleanKey }
                }));
                roomItem = getResult.Item;
            } catch (e) {}

            if (!roomItem) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_USERS,
                    Limit: 150
                }));
                const cleanCode = rawId.replace(/^PF-/i, "").toLowerCase();
                roomItem = (scanResult.Items || []).find(r => {
                    const rId = (r.id || "").toString().toLowerCase();
                    const rCode = (r.roomCode || "").toString().replace(/^PF-/i, "").toLowerCase();
                    return rId === rawId.toLowerCase() || rCode === cleanCode;
                });
            }

            if (roomItem) {
                const messages = Array.isArray(roomItem.chatMessages) ? [...roomItem.chatMessages] : [];
                messages.push({
                    id: message.id || `rmsg_${Date.now()}_${Math.random()}`,
                    senderName: message.senderName || "Player",
                    senderPhoto: message.senderPhoto || null,
                    senderColor: message.senderColor || null,
                    level: message.level || 1,
                    message: message.message || "",
                    time: message.time || new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
                    isGiftAnnouncement: message.isGiftAnnouncement === true,
                    gift: message.gift || null,
                    recipientName: message.recipientName || null,
                    timestamp: Date.now()
                });
                roomItem.chatMessages = messages.slice(-100);
                roomItem.Email = roomItem.Email || cleanKey;
                roomItem.updatedAt = new Date().toISOString();
                await docClient.send(new PutCommand({
                    TableName: TABLE_USERS,
                    Item: roomItem
                }));
                return makeResponse(200, { success: true, count: roomItem.chatMessages.length, messages: roomItem.chatMessages });
            }
            return makeResponse(404, { success: false, error: "Room not found" });
        }

        if (action === "clearRoomChat") {
            const rawId = (body.roomId || body.id || body.roomCode || "").toString();
            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;
            let roomItem = null;
            try {
                const getResult = await docClient.send(new GetCommand({
                    TableName: TABLE_USERS,
                    Key: { Email: cleanKey }
                }));
                roomItem = getResult.Item;
            } catch (e) {}

            if (!roomItem) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_USERS,
                    Limit: 150
                }));
                const cleanCode = rawId.replace(/^PF-/i, "").toLowerCase();
                roomItem = (scanResult.Items || []).find(r => {
                    const rId = (r.id || "").toString().toLowerCase();
                    const rCode = (r.roomCode || "").toString().replace(/^PF-/i, "").toLowerCase();
                    return rId === rawId.toLowerCase() || rCode === cleanCode;
                });
            }

            if (roomItem) {
                roomItem.chatMessages = [];
                roomItem.Email = roomItem.Email || cleanKey;
                roomItem.updatedAt = new Date().toISOString();
                await docClient.send(new PutCommand({
                    TableName: TABLE_USERS,
                    Item: roomItem
                }));
                return makeResponse(200, { success: true });
            }
            return makeResponse(404, { success: false, error: "Room not found" });
        }

        // ---------------------------------------------------------------------
        // 14. ROOM STATE & REAL-TIME POLLING (MEMBERS, SEATS, SONG, DELETION)
        // ---------------------------------------------------------------------
        if (action === "getRoomState" || action === "getRoomMembers") {
            const rawId = (body.roomId || body.id || body.roomCode || "").toString();
            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;

            let roomItem = null;
            try {
                const getResult = await docClient.send(new GetCommand({
                    TableName: TABLE_USERS,
                    Key: { Email: cleanKey }
                }));
                roomItem = getResult.Item;
            } catch (e) {}

            // Fallback: search by roomCode or id
            if (!roomItem) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_USERS,
                    Limit: 150
                }));
                const cleanCode = rawId.replace(/^PF-/i, "").toLowerCase();
                roomItem = (scanResult.Items || []).find(r => {
                    if (r.entityType !== "ROOM" && !(r.Email && r.Email.startsWith("ROOM#"))) return false;
                    const rId = (r.id || "").toString().toLowerCase();
                    const rCode = (r.roomCode || "").toString().replace(/^PF-/i, "").toLowerCase();
                    return rId === rawId.toLowerCase() || rCode === cleanCode;
                });
            }

            if (!roomItem || roomItem.isDeleted === true) {
                return makeResponse(404, {
                    success: false,
                    roomDeleted: true,
                    error: "This room has been closed by the host."
                });
            }

            return makeResponse(200, {
                success: true,
                room: roomItem,
                members: roomItem.members || [],
                seats: roomItem.seats || [],
                currentSong: roomItem.currentSong || null,
                currentPlayers: (roomItem.members || []).length,
                chatMessages: roomItem.chatMessages || [],
                kickedUsers: roomItem.kickedUsers || []
            });
        }

        if (action === "joinRoom") {
            const rawId = (body.roomId || body.id || body.roomCode || "").toString();
            const user = body.user || {};
            const userId = (user.id || user.userId || "").toString();

            if (!rawId || !userId) {
                return makeResponse(400, { success: false, error: "roomId and user are required." });
            }

            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;
            let roomItem = null;
            try {
                const getResult = await docClient.send(new GetCommand({
                    TableName: TABLE_USERS,
                    Key: { Email: cleanKey }
                }));
                roomItem = getResult.Item;
            } catch (e) {}

            if (!roomItem) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_USERS,
                    Limit: 150
                }));
                const cleanCode = rawId.replace(/^PF-/i, "").toLowerCase();
                roomItem = (scanResult.Items || []).find(r => {
                    if (r.entityType !== "ROOM" && !(r.Email && r.Email.startsWith("ROOM#"))) return false;
                    const rId = (r.id || "").toString().toLowerCase();
                    const rCode = (r.roomCode || "").toString().replace(/^PF-/i, "").toLowerCase();
                    return rId === rawId.toLowerCase() || rCode === cleanCode;
                });
            }

            if (!roomItem || roomItem.isDeleted === true) {
                return makeResponse(404, { success: false, roomDeleted: true, error: "Room not found or closed." });
            }

            const members = Array.isArray(roomItem.members) ? [...roomItem.members] : [];
            const existingIdx = members.findIndex(m => m.userId === userId);

            const newMember = {
                userId: userId,
                name: user.name || "Player",
                gamerTag: user.tag || user.gamerTag || "@player",
                profilePhoto: user.profilePhoto || null,
                role: (userId === roomItem.hostId || user.name === roomItem.hostName) ? "host" : "listener",
                joinedAt: new Date().toISOString()
            };

            if (existingIdx !== -1) {
                members[existingIdx] = newMember;
            } else {
                members.push(newMember);
            }

            roomItem.members = members;
            roomItem.currentPlayers = members.length;
            roomItem.updatedAt = new Date().toISOString();
            roomItem.Email = roomItem.Email || `ROOM#${roomItem.id}`;

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: roomItem
            }));

            return makeResponse(200, {
                success: true,
                room: roomItem,
                members: members,
                seats: roomItem.seats || [],
                currentSong: roomItem.currentSong || null,
                currentPlayers: members.length
            });
        }

        if (action === "leaveRoom") {
            const rawId = (body.roomId || body.id || "").toString();
            const userId = (body.userId || "").toString();

            if (!rawId || !userId) {
                return makeResponse(400, { success: false, error: "roomId and userId are required." });
            }

            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;
            let roomItem = null;
            try {
                const getResult = await docClient.send(new GetCommand({
                    TableName: TABLE_USERS,
                    Key: { Email: cleanKey }
                }));
                roomItem = getResult.Item;
            } catch (e) {}

            if (!roomItem) {
                return makeResponse(200, { success: true, message: "Room already closed." });
            }

            let members = Array.isArray(roomItem.members) ? [...roomItem.members] : [];
            members = members.filter(m => m.userId !== userId);

            // Also vacate any seat held by this user
            const seats = Array.isArray(roomItem.seats) ? [...roomItem.seats] : [];
            for (let i = 0; i < seats.length; i++) {
                if (seats[i] && (seats[i].userId === userId || seats[i].userName === body.userName)) {
                    seats[i] = null;
                }
            }

            roomItem.members = members;
            roomItem.seats = seats;
            roomItem.currentPlayers = members.length;
            roomItem.updatedAt = new Date().toISOString();

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: roomItem
            }));

            return makeResponse(200, {
                success: true,
                members: members,
                seats: seats,
                currentPlayers: members.length
            });
        }

        // ---------------------------------------------------------------------
        // 15. MIC SEATS REAL-TIME SYNCHRONIZATION
        // ---------------------------------------------------------------------
        if (action === "takeSeat") {
            const rawId = (body.roomId || body.id || "").toString();
            const seatIndex = parseInt(body.seatIndex, 10);
            const user = body.user || {};
            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;

            const getResult = await docClient.send(new GetCommand({
                TableName: TABLE_USERS,
                Key: { Email: cleanKey }
            }));

            const roomItem = getResult.Item;
            if (!roomItem || roomItem.isDeleted === true) {
                return makeResponse(404, { success: false, roomDeleted: true, error: "Room not found or closed." });
            }

            const seats = Array.isArray(roomItem.seats) && roomItem.seats.length === 8
                ? [...roomItem.seats]
                : [null, null, null, null, null, null, null, null];

            const userId = (user.id || user.userId || "").toString();
            const userName = user.name || "Player";

            // Vacate any previous seat held by this user
            for (let i = 0; i < seats.length; i++) {
                if (seats[i] && (seats[i].userId === userId || seats[i].userName === userName)) {
                    seats[i] = null;
                }
            }

            // Assign new seat
            if (seatIndex >= 0 && seatIndex < 8) {
                seats[seatIndex] = {
                    seatIndex: seatIndex + 1,
                    userId: userId,
                    userName: userName,
                    userPhoto: user.profilePhoto || null,
                    userColor: user.avatarColor || 0xFF3B82F6,
                    level: user.level || 1,
                    isHost: seatIndex === 0 || userName === roomItem.hostName,
                    isMuted: false,
                    isSpeaking: true
                };
            }

            roomItem.seats = seats;
            roomItem.updatedAt = new Date().toISOString();

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: roomItem
            }));

            return makeResponse(200, { success: true, seats: seats });
        }

        if (action === "leaveSeat") {
            const rawId = (body.roomId || body.id || "").toString();
            const seatIndex = parseInt(body.seatIndex, 10);
            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;

            const getResult = await docClient.send(new GetCommand({
                TableName: TABLE_USERS,
                Key: { Email: cleanKey }
            }));

            const roomItem = getResult.Item;
            if (!roomItem) {
                return makeResponse(200, { success: true });
            }

            const seats = Array.isArray(roomItem.seats) ? [...roomItem.seats] : [];
            if (seatIndex >= 0 && seatIndex < seats.length) {
                seats[seatIndex] = null;
            }

            roomItem.seats = seats;
            roomItem.updatedAt = new Date().toISOString();

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: roomItem
            }));

            return makeResponse(200, { success: true, seats: seats });
        }

        // ---------------------------------------------------------------------
        // 16. ROOM MUSIC REAL-TIME SYNCHRONIZATION
        // ---------------------------------------------------------------------
        if (action === "syncRoomMusic") {
            const rawId = (body.roomId || body.id || "").toString();
            const song = body.song || body.currentSong || {};
            const cleanKey = rawId.startsWith("ROOM#") ? rawId : `ROOM#${rawId}`;

            const getResult = await docClient.send(new GetCommand({
                TableName: TABLE_USERS,
                Key: { Email: cleanKey }
            }));

            const roomItem = getResult.Item;
            if (!roomItem || roomItem.isDeleted === true) {
                return makeResponse(404, { success: false, roomDeleted: true, error: "Room not found or closed." });
            }

            roomItem.currentSong = {
                id: song.id ?? 0,
                title: song.title || "Room Track",
                genre: song.genre || "Game Audio",
                bpm: song.bpm || "120 BPM",
                isPlaying: song.isPlaying !== false,
                trackIndex: song.trackIndex ?? 0,
                audioSource: song.audioSource || null,
                updatedAt: new Date().toISOString()
            };
            roomItem.updatedAt = new Date().toISOString();

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: roomItem
            }));

            return makeResponse(200, { success: true, currentSong: roomItem.currentSong });
        }

        // ---------------------------------------------------------------------
        // 17. DIRECT MESSAGING (PERSISTED IN SINGLE-TABLE DynamoDB)
        // ---------------------------------------------------------------------
        if (action === "sendDirectMessage") {
            const senderId = (body.senderId || "").toString().trim();
            const receiverId = (body.receiverId || "").toString().trim();
            const text = body.text || body.message || "";

            if (!senderId || !receiverId || !text) {
                return makeResponse(400, { success: false, error: "senderId, receiverId, and text are required." });
            }

            const convId = [senderId, receiverId].sort().join("_");
            const timestamp = Date.now();
            const rand = Math.random().toString(36).substring(2, 6);

            const msgItem = {
                Email: `MSG#${convId}#${timestamp}_${rand}`,
                entityType: "MESSAGE",
                id: `msg_${timestamp}_${rand}`,
                conversationId: convId,
                senderId: senderId,
                receiverId: receiverId,
                text: text,
                createdAt: new Date().toISOString()
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: msgItem
            }));

            return makeResponse(201, { success: true, message: msgItem });
        }

        if (action === "getDirectMessages") {
            const userA = (body.userA || body.senderId || "").toString().trim();
            const userB = (body.userB || body.receiverId || "").toString().trim();
            const convId = [userA, userB].sort().join("_");

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const items = (scanResult.Items || [])
                .filter(m => (m.entityType === "MESSAGE" || (m.Email && m.Email.startsWith("MSG#"))) && m.conversationId === convId)
                .sort((a, b) => (a.createdAt || "").localeCompare(b.createdAt || ""));

            return makeResponse(200, { success: true, messages: items });
        }

        // ---------------------------------------------------------------------
        // 18. PROFILE PHOTO & SONGS
        // ---------------------------------------------------------------------
        if (action === "updateProfilePhoto" || action === "deleteProfilePhoto") {
            const rawId = (body.email || body.userId || "").toLowerCase().trim();
            const photoUrl = action === "deleteProfilePhoto" ? null : (body.photoUrl || body.profilePhoto || null);

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const user = (scanResult.Items || []).find(u => {
                const email = (u.email || u.Email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                return email === rawId || id === rawId;
            });

            if (!user) {
                return makeResponse(404, { success: false, error: "User not found." });
            }

            user.profilePhoto = photoUrl;
            user.updatedAt = new Date().toISOString();
            user.Email = user.Email || user.email;

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: user
            }));

            return makeResponse(200, { success: true, profilePhoto: photoUrl });
        }

        if (action === "uploadSong") {
            const song = body.song || body;
            const songId = song.id || Date.now();
            const item = {
                Email: `SONG#${song.userId || "01"}#${songId}`,
                entityType: "SONG",
                ...song,
                createdAt: new Date().toISOString()
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: item
            }));

            return makeResponse(201, { success: true, song: item });
        }

        if (action === "getUserSongs") {
            const userId = (body.userId || "").toString();
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const songs = (scanResult.Items || []).filter(s =>
                (s.entityType === "SONG" || (s.Email && s.Email.startsWith("SONG#"))) &&
                (!userId || (s.userId || "").toString() === userId)
            );

            return makeResponse(200, { success: true, songs });
        }

        if (action === "sendOtpEmail" || action === "dispatchBrevoEmail") {
            return makeResponse(200, {
                success: true,
                message: "OTP relay accepted",
                provider: "Brevo-Relay"
            });
        }

        return makeResponse(400, {
            success: false,
            error: `Unsupported action: '${action}'.`
        });

    } catch (error) {
        console.error("PlayFriends Handler Error:", error);
        return makeResponse(500, {
            success: false,
            error: error.message || "Internal server error"
        });
    }
};

