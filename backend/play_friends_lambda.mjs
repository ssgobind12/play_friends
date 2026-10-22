// =============================================================================
// Play Friends - Authoritative Production AWS Lambda Handler (Node.js 20.x)
// Table: PlayFriends_Users (Primary Key: email [String])
// Region: ap-southeast-2 (Sydney)
// Zero external npm dependencies: uses built-in AWS SDK v3 in Lambda runtime
// =============================================================================

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
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
const TABLE_ROOMS = `${TABLE_USERS}_Rooms`;
const TABLE_SONGS = `${TABLE_USERS}_Songs`;
const TABLE_MESSAGES = `${TABLE_USERS}_Messages`;

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
        // 2. CHECK USER UNIQUENESS (EMAIL, MOBILE, GAMER TAG)
        // ---------------------------------------------------------------------
        if (action === "checkUser") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || body.mobile || "").replace(/\D/g, "");
            const tag = (body.tag || body.gamerTag || "").toLowerCase().trim().replace(/^@/, "");

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            for (const item of (scanResult.Items || [])) {
                const itemEmail = (item.email || "").toLowerCase().trim();
                const itemPhone = (item.phoneNumber || "").replace(/\D/g, "");
                const itemTag = (item.tag || item.gamerTag || "").toLowerCase().replace(/^@/, "");

                if (email && itemEmail && itemEmail === email) {
                    return makeResponse(200, {
                        exists: true,
                        field: "email",
                        message: "This email is already registered. Please sign in or use another email."
                    });
                }

                if (phone && phone.length >= 7 && itemPhone) {
                    if (itemPhone === phone || itemPhone.endsWith(phone) || phone.endsWith(itemPhone)) {
                        // Only block if account has credentials configured
                        if (item.password || item.passwordHash) {
                            return makeResponse(200, {
                                exists: true,
                                field: "mobile",
                                message: "This mobile number is already registered in AWS. Please sign in or use another number."
                            });
                        }
                    }
                }

                if (tag && itemTag === tag && itemEmail !== email) {
                    return makeResponse(200, {
                        exists: true,
                        field: "tag",
                        message: "This gamer tag is already taken. Please choose another."
                    });
                }
            }

            return makeResponse(200, { exists: false });
        }

        // ---------------------------------------------------------------------
        // 3. REGISTER: Persist account, credentials, and social fields in DynamoDB
        // ---------------------------------------------------------------------
        if (action === "register") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").trim();
            const password = (body.password || "").trim();
            const passwordHash = (body.passwordHash || "").trim();

            if (!email) {
                return makeResponse(400, { success: false, error: "Email is required for registration." });
            }

            // Generate clean unique gamer tag if not supplied
            let tag = (body.tag || body.gamerTag || "").trim();
            if (!tag) {
                const prefix = email.split("@")[0].replace(/[^a-zA-Z0-9_]/g, "_");
                tag = "@" + prefix.toLowerCase();
            }
            if (!tag.startsWith("@")) tag = "@" + tag;

            // Generate stable security ID
            const userId = body.userId || body.id || ("01" + Math.floor(100000 + Math.random() * 900000));

            const item = {
                email: email,
                phoneNumber: phone,
                userId: userId,
                securityId: userId,
                id: userId,
                name: body.name || "Player",
                tag: tag,
                gamerTag: tag,
                countryCode: body.countryCode || "+91",
                countryFlag: body.countryFlag || "🇮🇳",
                password: password || passwordHash,
                passwordHash: passwordHash || password,
                level: body.level || 1,
                coins: body.coins || 500,
                trophies: body.trophies || 0,
                followers: [],
                following: [],
                followersCount: 0,
                followingCount: 0,
                visitorsCount: 10,
                role: body.role || "user",
                createdAt: body.registeredAt || new Date().toISOString(),
                updatedAt: new Date().toISOString()
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: item
            }));

            const sessionToken = "pf_sess_" + Math.random().toString(36).substring(2) + Date.now().toString(36);

            return makeResponse(201, {
                success: true,
                message: "User and credentials stored in AWS DynamoDB successfully",
                user: item,
                sessionToken: sessionToken
            });
        }

        // ---------------------------------------------------------------------
        // 4. LOGIN: Supports Email, Mobile Number, Gamer Tag (@tag), or Security ID
        // ---------------------------------------------------------------------
        if (action === "login") {
            const rawId = (body.identifier || body.email || body.phoneNumber || body.tag || "").trim();
            const password = (body.password || "").trim();

            if (!rawId || !password) {
                return makeResponse(400, { success: false, error: "Please enter your credentials." });
            }

            const cleanEmail = rawId.toLowerCase();
            const cleanDigits = rawId.replace(/\D/g, "");
            const cleanTag = rawId.toLowerCase().replace(/^@/, "");

            let userItem = null;

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            for (const item of (scanResult.Items || [])) {
                const itemEmail = (item.email || "").toLowerCase().trim();
                const itemPhone = (item.phoneNumber || "").replace(/\D/g, "");
                const itemTag = (item.tag || item.gamerTag || "").toLowerCase().replace(/^@/, "");
                const itemId = (item.userId || item.id || item.securityId || "").toLowerCase().trim();

                if (
                    (cleanEmail && itemEmail === cleanEmail) ||
                    (cleanDigits && cleanDigits.length >= 7 && (itemPhone === cleanDigits || itemPhone.endsWith(cleanDigits) || cleanDigits.endsWith(itemPhone))) ||
                    (cleanTag && itemTag === cleanTag) ||
                    (itemId && itemId === rawId.toLowerCase())
                ) {
                    userItem = item;
                    break;
                }
            }

            if (!userItem) {
                return makeResponse(404, {
                    success: false,
                    error: "Account not found. Please check your credentials or register."
                });
            }

            // Verify password
            const isMatch = verifyPassword(password, userItem.password, userItem.passwordHash);
            if (!isMatch) {
                // If legacy record without password, adopt this password on first login
                if (!userItem.password && !userItem.passwordHash) {
                    userItem.password = password;
                    userItem.passwordHash = password;
                    userItem.updatedAt = new Date().toISOString();
                    await docClient.send(new PutCommand({
                        TableName: TABLE_USERS,
                        Item: userItem
                    }));
                } else {
                    return makeResponse(401, {
                        success: false,
                        error: "Incorrect password. Please try again."
                    });
                }
            }

            const clientUser = {
                id: userItem.userId || userItem.id || "01000000",
                userId: userItem.userId || userItem.id || "01000000",
                securityId: userItem.userId || userItem.id || "01000000",
                name: userItem.name || "Player",
                tag: userItem.tag || userItem.gamerTag || ("@" + (userItem.name || "player").toLowerCase().replace(/\s+/g, "_")),
                gamerTag: userItem.tag || userItem.gamerTag || ("@" + (userItem.name || "player").toLowerCase().replace(/\s+/g, "_")),
                email: userItem.email,
                phoneNumber: userItem.phoneNumber,
                countryCode: userItem.countryCode || "+91",
                countryFlag: userItem.countryFlag || "🇮🇳",
                level: userItem.level || 1,
                coins: userItem.coins || 500,
                trophies: userItem.trophies || 0,
                profilePhoto: userItem.profilePhoto || null,
                followersCount: Array.isArray(userItem.followers) ? userItem.followers.length : (userItem.followersCount || 0),
                followingCount: Array.isArray(userItem.following) ? userItem.following.length : (userItem.followingCount || 0),
                visitorsCount: userItem.visitorsCount || 10,
                role: userItem.role || "user"
            };

            const sessionToken = "pf_sess_" + Math.random().toString(36).substring(2) + Date.now().toString(36);

            return makeResponse(200, {
                success: true,
                user: clientUser,
                sessionToken: sessionToken
            });
        }

        // ---------------------------------------------------------------------
        // 5. VALIDATE SESSION / LOGOUT
        // ---------------------------------------------------------------------
        if (action === "validateSession") {
            const token = body.sessionToken || body.token;
            if (!token || !token.startsWith("pf_sess_")) {
                return makeResponse(401, { success: false, error: "Invalid session." });
            }
            return makeResponse(200, { success: true, message: "Session valid." });
        }

        if (action === "logout") {
            return makeResponse(200, { success: true, message: "Logged out successfully." });
        }

        // ---------------------------------------------------------------------
        // 6. RESET PASSWORD
        // ---------------------------------------------------------------------
        if (action === "resetPassword") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").replace(/\D/g, "");
            const newPassword = (body.newPassword || "").trim();

            if (!newPassword) {
                return makeResponse(400, { success: false, error: "New password is required." });
            }

            const scanRes = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));
            const userItem = (scanRes.Items || []).find(u => {
                const itemEmail = (u.email || "").toLowerCase().trim();
                const p = (u.phoneNumber || "").replace(/\D/g, "");
                return (email && itemEmail === email) || (phone && p === phone);
            });

            if (!userItem) {
                return makeResponse(404, { success: false, error: "Account not found." });
            }

            userItem.password = newPassword;
            userItem.passwordHash = newPassword;
            userItem.updatedAt = new Date().toISOString();
            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: userItem
            }));

            return makeResponse(200, { success: true, message: "Password updated successfully on server." });
        }

        // ---------------------------------------------------------------------
        // 7. LIST USERS & DIRECTORY
        // ---------------------------------------------------------------------
        if (action === "listUsers" || action === "getAllUsers") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 200
            }));
            const users = (scanResult.Items || []).map(u => ({
                id: u.userId || u.id || "01000000",
                userId: u.userId || u.id || "01000000",
                securityId: u.userId || u.id || "01000000",
                name: u.name || "Player",
                gamerTag: u.tag || u.gamerTag || ("@" + (u.name || "player").toLowerCase().replace(/\s+/g, "_")),
                email: u.email,
                phoneNumber: u.phoneNumber,
                level: u.level || 1,
                coins: u.coins || 500,
                trophies: u.trophies || 0,
                profilePhoto: u.profilePhoto || null,
                followersCount: Array.isArray(u.followers) ? u.followers.length : (u.followersCount || 0),
                followingCount: Array.isArray(u.following) ? u.following.length : (u.followingCount || 0),
                visitorsCount: u.visitorsCount || 10,
                createdAt: u.createdAt
            }));
            return makeResponse(200, users);
        }

        // ---------------------------------------------------------------------
        // 8. SEARCH USERS
        // ---------------------------------------------------------------------
        if (action === "searchUsers") {
            const raw = (body.query || body.q || "").toLowerCase().trim();
            const cleanQ = raw.replace(/^@/, "");
            if (!cleanQ) {
                return makeResponse(200, []);
            }

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 100
            }));

            const matched = [];
            for (const u of (scanResult.Items || [])) {
                const uId = (u.userId || u.id || u.securityId || "").toLowerCase();
                const uTag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                const uName = (u.name || "").toLowerCase();
                const uEmail = (u.email || "").toLowerCase();

                if (uId.includes(cleanQ) || uTag.includes(cleanQ) || uName.includes(cleanQ) || uEmail.includes(cleanQ)) {
                    matched.push({
                        id: u.userId || u.id || "01000000",
                        userId: u.userId || u.id || "01000000",
                        securityId: u.userId || u.id || "01000000",
                        name: u.name || "Player",
                        tag: u.tag || ("@" + (u.name || "player").toLowerCase().replace(/\s+/g, "_")),
                        gamerTag: u.tag || ("@" + (u.name || "player").toLowerCase().replace(/\s+/g, "_")),
                        email: u.email,
                        level: u.level || 1,
                        coins: u.coins || 500,
                        trophies: u.trophies || 0,
                        profilePhoto: u.profilePhoto || null,
                        followersCount: Array.isArray(u.followers) ? u.followers.length : (u.followersCount || 0),
                        followingCount: Array.isArray(u.following) ? u.following.length : (u.followingCount || 0),
                        visitorsCount: u.visitorsCount || 10
                    });
                }
            }

            return makeResponse(200, matched);
        }

        // ---------------------------------------------------------------------
        // 9. SOCIAL GRAPH: FOLLOW / UNFOLLOW USER
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

            let followerUser = null;
            let targetUser = null;

            for (const item of (scanResult.Items || [])) {
                const itemEmail = (item.email || "").toLowerCase();
                const itemTag = (item.tag || item.gamerTag || "").toLowerCase().replace(/^@/, "");
                const itemId = (item.userId || item.id || "").toLowerCase();

                if (!followerUser && (itemEmail === followerId || itemId === followerId || itemTag === followerId.replace(/^@/, ""))) {
                    followerUser = item;
                }
                if (!targetUser && (itemEmail === targetId || itemId === targetId || itemTag === targetId)) {
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
            const followerKey = followerUser ? (followerUser.userId || followerUser.email) : followerId;

            if (follow) {
                if (!targetFollowers.includes(followerKey)) {
                    targetFollowers.push(followerKey);
                }
            } else {
                const idx = targetFollowers.indexOf(followerKey);
                if (idx !== -1) targetFollowers.splice(idx, 1);
            }

            targetUser.followers = targetFollowers;
            targetUser.followersCount = targetFollowers.length;
            targetUser.updatedAt = new Date().toISOString();

            await docClient.send(new PutCommand({
                TableName: TABLE_USERS,
                Item: targetUser
            }));

            // Update Follower's following list
            let followingCount = 0;
            if (followerUser) {
                const followerFollowing = Array.isArray(followerUser.following) ? [...followerUser.following] : [];
                const targetKey = targetUser.userId || targetUser.email;

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
        // 10. SOCIAL GRAPH: GET FOLLOWERS & FOLLOWING
        // ---------------------------------------------------------------------
        if (action === "getFollowers" || action === "getFollowing") {
            const rawId = (body.userId || body.email || body.tag || "").toLowerCase().trim().replace(/^@/, "");

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const items = scanResult.Items || [];
            const target = items.find(u => {
                const email = (u.email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                return email === rawId || id === rawId || tag === rawId;
            });

            if (!target) {
                return makeResponse(200, { success: true, list: [], count: 0 });
            }

            const keyList = action === "getFollowers" ? (target.followers || []) : (target.following || []);
            const resultList = [];

            for (const key of keyList) {
                const match = items.find(u => {
                    const email = (u.email || "").toLowerCase();
                    const id = (u.userId || u.id || "").toLowerCase();
                    return email === key.toLowerCase() || id === key.toLowerCase();
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
                    resultList.push({ id: key, name: "Player", tag: "@player" });
                }
            }

            return makeResponse(200, { success: true, list: resultList, count: resultList.length });
        }

        // ---------------------------------------------------------------------
        // 11. SOCIAL GRAPH: GET FOLLOW STATUS & MUTUAL FRIENDSHIP
        // ---------------------------------------------------------------------
        if (action === "getFollowStatus") {
            const currentId = (body.currentUserId || body.followerId || "").toLowerCase().trim();
            const targetId = (body.targetUserId || body.targetId || "").toLowerCase().trim().replace(/^@/, "");

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));

            const items = scanResult.Items || [];
            const currentUser = items.find(u => (u.userId || u.id || u.email || "").toLowerCase() === currentId);
            const targetUser = items.find(u => {
                const email = (u.email || "").toLowerCase();
                const id = (u.userId || u.id || "").toLowerCase();
                const tag = (u.tag || u.gamerTag || "").toLowerCase().replace(/^@/, "");
                return email === targetId || id === targetId || tag === targetId;
            });

            let isFollowing = false;
            let isFollowedBy = false;

            if (currentUser && targetUser) {
                const cId = currentUser.userId || currentUser.email;
                const tId = targetUser.userId || targetUser.email;

                isFollowing = Array.isArray(currentUser.following) && currentUser.following.includes(tId);
                isFollowedBy = Array.isArray(targetUser.following) && targetUser.following.includes(cId);
            }

            return makeResponse(200, {
                success: true,
                isFollowing,
                isFollowedBy,
                isMutual: isFollowing && isFollowedBy
            });
        }

        // ---------------------------------------------------------------------
        // 12. ROOM MANAGEMENT (CREATE, LIST, DELETE)
        // ---------------------------------------------------------------------
        if (action === "getRooms") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_ROOMS,
                Limit: 50
            }));

            // Filter out legacy demo rooms
            const rooms = (scanResult.Items || []).filter(r => {
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

            const item = {
                ...room,
                id: roomId,
                roomCode: room.roomCode || `PF-${Math.floor(1000 + Math.random() * 9000)}`,
                members: [
                    {
                        userId: hostUser.id || hostUser.userId || room.hostId || "host_01",
                        name: room.hostName || hostUser.name || "Host Player",
                        gamerTag: hostUser.tag || hostUser.gamerTag || "@host",
                        profilePhoto: room.hostPhoto || hostUser.profilePhoto || null,
                        role: "host",
                        joinedAt: new Date().toISOString()
                    }
                ],
                currentPlayers: 1,
                updatedAt: new Date().toISOString()
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_ROOMS,
                Item: item
            }));

            return makeResponse(201, { success: true, room: item });
        }

        if (action === "deleteRoom") {
            const roomId = body.roomId || body.id;
            if (roomId) {
                await docClient.send(new DeleteCommand({
                    TableName: TABLE_ROOMS,
                    Key: { id: roomId }
                }));
            }
            return makeResponse(200, { success: true });
        }

        // ---------------------------------------------------------------------
        // 13. ROOM MEMBERSHIP: JOIN ROOM & LEAVE ROOM (CROSS-DEVICE SYNC)
        // ---------------------------------------------------------------------
        if (action === "joinRoom") {
            const roomId = body.roomId || body.id;
            const user = body.user || {};
            const userId = (user.id || user.userId || "").toString();

            if (!roomId || !userId) {
                return makeResponse(400, { success: false, error: "roomId and user are required." });
            }

            const getResult = await docClient.send(new GetCommand({
                TableName: TABLE_ROOMS,
                Key: { id: roomId }
            }));

            let roomItem = getResult.Item;
            if (!roomItem) {
                return makeResponse(404, { success: false, error: "Room not found." });
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

            await docClient.send(new PutCommand({
                TableName: TABLE_ROOMS,
                Item: roomItem
            }));

            return makeResponse(200, {
                success: true,
                room: roomItem,
                members: members,
                currentPlayers: members.length
            });
        }

        if (action === "leaveRoom") {
            const roomId = body.roomId || body.id;
            const userId = (body.userId || "").toString();

            if (!roomId || !userId) {
                return makeResponse(400, { success: false, error: "roomId and userId are required." });
            }

            const getResult = await docClient.send(new GetCommand({
                TableName: TABLE_ROOMS,
                Key: { id: roomId }
            }));

            let roomItem = getResult.Item;
            if (!roomItem) {
                return makeResponse(200, { success: true, message: "Room already closed." });
            }

            let members = Array.isArray(roomItem.members) ? [...roomItem.members] : [];
            members = members.filter(m => m.userId !== userId);

            roomItem.members = members;
            roomItem.currentPlayers = members.length;
            roomItem.updatedAt = new Date().toISOString();

            // If room is empty or host leaves without members, safely update
            await docClient.send(new PutCommand({
                TableName: TABLE_ROOMS,
                Item: roomItem
            }));

            return makeResponse(200, {
                success: true,
                members: members,
                currentPlayers: members.length
            });
        }

        if (action === "getRoomMembers") {
            const roomId = body.roomId || body.id;
            const getResult = await docClient.send(new GetCommand({
                TableName: TABLE_ROOMS,
                Key: { id: roomId }
            }));

            const roomItem = getResult.Item;
            if (!roomItem) {
                return makeResponse(404, { success: false, error: "Room not found." });
            }

            const members = Array.isArray(roomItem.members) ? roomItem.members : [];
            return makeResponse(200, {
                success: true,
                members: members,
                currentPlayers: members.length
            });
        }

        // ---------------------------------------------------------------------
        // 14. DIRECT MESSAGING & ROOM CHAT
        // ---------------------------------------------------------------------
        if (action === "sendDirectMessage") {
            const senderId = body.senderId;
            const receiverId = body.receiverId;
            const text = body.text || body.message || "";

            if (!senderId || !receiverId || !text) {
                return makeResponse(400, { success: false, error: "senderId, receiverId, and text are required." });
            }

            const msgItem = {
                id: `msg_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
                conversationId: [senderId, receiverId].sort().join("_"),
                senderId: senderId,
                receiverId: receiverId,
                text: text,
                createdAt: new Date().toISOString()
            };

            await docClient.send(new PutCommand({
                TableName: TABLE_MESSAGES,
                Item: msgItem
            }));

            return makeResponse(201, { success: true, message: msgItem });
        }

        if (action === "getDirectMessages") {
            const userA = body.userA || body.senderId;
            const userB = body.userB || body.receiverId;
            const conversationId = [userA, userB].sort().join("_");

            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_MESSAGES,
                FilterExpression: "conversationId = :cid",
                ExpressionAttributeValues: { ":cid": conversationId },
                Limit: 100
            }));

            const items = (scanResult.Items || []).sort((a, b) => (a.createdAt || "").localeCompare(b.createdAt || ""));
            return makeResponse(200, { success: true, messages: items });
        }

        // ---------------------------------------------------------------------
        // 15. PROFILE PHOTO & DELETE USER
        // ---------------------------------------------------------------------
        if (action === "updateProfilePhoto" || action === "deleteProfilePhoto") {
            const rawId = (body.email || body.userId || "").toLowerCase().trim();
            const photo = action === "deleteProfilePhoto" ? null : body.profilePhoto;

            if (rawId) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_USERS,
                    Limit: 250
                }));
                const userItem = (scanResult.Items || []).find(u => {
                    const itemEmail = (u.email || "").toLowerCase().trim();
                    const itemId = (u.userId || u.id || "").toLowerCase().trim();
                    return itemEmail === rawId || itemId === rawId;
                });

                if (userItem) {
                    userItem.profilePhoto = photo;
                    userItem.updatedAt = new Date().toISOString();
                    await docClient.send(new PutCommand({
                        TableName: TABLE_USERS,
                        Item: userItem
                    }));
                }
            }

            return makeResponse(200, { success: true, message: "Profile photo updated on server." });
        }

        if (action === "deleteUser") {
            const rawId = (body.email || body.userId || "").toLowerCase().trim();
            if (rawId) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_USERS,
                    Limit: 250
                }));
                const userItem = (scanResult.Items || []).find(u => {
                    const itemEmail = (u.email || "").toLowerCase().trim();
                    const itemId = (u.userId || u.id || "").toLowerCase().trim();
                    return itemEmail === rawId || itemId === rawId;
                });
                if (userItem && userItem.id) {
                    await docClient.send(new DeleteCommand({
                        TableName: TABLE_USERS,
                        Key: { id: userItem.id }
                    }));
                }
            }
            return makeResponse(200, { success: true, message: "User deleted from server." });
        }

        if (action === "deleteAllUsers" || action === "clearAllUsers") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_USERS,
                Limit: 250
            }));
            let deletedCount = 0;
            for (const item of (scanResult.Items || [])) {
                if (item.id) {
                    await docClient.send(new DeleteCommand({
                        TableName: TABLE_USERS,
                        Key: { id: item.id }
                    }));
                    deletedCount++;
                }
            }
            return makeResponse(200, {
                success: true,
                message: `Successfully deleted all ${deletedCount} users from AWS DynamoDB.`,
                deletedCount
            });
        }

        // ---------------------------------------------------------------------
        // 16. SONGS
        // ---------------------------------------------------------------------
        if (action === "uploadSong") {
            const song = body.song || {};
            await docClient.send(new PutCommand({
                TableName: TABLE_SONGS,
                Item: { ...song, updatedAt: new Date().toISOString() }
            }));
            return makeResponse(200, { success: true, message: "Song saved to server." });
        }

        if (action === "getUserSongs") {
            const userId = body.userId;
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_SONGS,
                FilterExpression: "userId = :uid",
                ExpressionAttributeValues: { ":uid": userId }
            }));
            return makeResponse(200, { success: true, songs: scanResult.Items || [] });
        }

        return makeResponse(400, { error: "Unknown action: " + action });
    } catch (err) {
        return makeResponse(500, { error: err.message });
    }
};

