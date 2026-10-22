// =============================================================================
// Play Friends - AWS Lambda Function Handler (Node.js 20.x)
// Table: PlayFriends_Users (Primary Key: email [String])
// Region: ap-southeast-2 (Sydney)
// =============================================================================

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand, ScanCommand, GetCommand, DeleteCommand } = require("@aws-sdk/lib-dynamodb");

const client = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(client);
const TABLE_NAME = process.env.TABLE_NAME || "PlayFriends_Users";

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

exports.handler = async (event) => {
    // Handle CORS OPTIONS preflight
    const httpMethod = (event.requestContext?.http?.method || event.httpMethod || "").toUpperCase();
    if (httpMethod === "OPTIONS") {
        return makeResponse(204, {});
    }

    let body = {};
    if (event.body) {
        body = typeof event.body === "string" ? JSON.parse(event.body) : event.body;
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
        // 2. LOGIN: Supports Email, Mobile Number, Gamer Tag, or Security ID
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
            if (rawId.includes("@") && rawId.includes(".")) {
                const getResult = await docClient.send(new GetCommand({
                    TableName: TABLE_NAME,
                    Key: { email: cleanEmail }
                }));
                if (getResult.Item) {
                    userItem = getResult.Item;
                }
            }
            
            if (!userItem) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_NAME,
                    Limit: 200
                }));
                
                for (const item of (scanResult.Items || [])) {
                    const itemEmail = (item.email || "").toLowerCase();
                    const itemPhone = (item.phoneNumber || "").replace(/\D/g, "");
                    const itemTag = (item.tag || item.gamerTag || "").toLowerCase().replace(/^@/, "");
                    const itemId = (item.userId || item.id || "").toLowerCase();
                    
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
            }
            
            if (!userItem) {
                return makeResponse(404, {
                    success: false,
                    error: "Account not found. Please check your credentials or register."
                });
            }
            
            // Password verification
            const storedPass = userItem.password || userItem.passwordHash;
            if (storedPass) {
                const isMatch = (storedPass === password) || (userItem.passwordHash && userItem.passwordHash === password);
                if (!isMatch) {
                    return makeResponse(401, {
                        success: false,
                        error: "Incorrect password. Please try again."
                    });
                }
            } else {
                // If legacy record without password, update their password so subsequent logins work
                userItem.password = password;
                userItem.updatedAt = new Date().toISOString();
                await docClient.send(new PutCommand({
                    TableName: TABLE_NAME,
                    Item: userItem
                }));
            }
            
            const clientUser = {
                id: userItem.userId || userItem.id || "01000000",
                userId: userItem.userId || userItem.id || "01000000",
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
        // 3. CHECK USER: Checks if email or mobile exists
        // ---------------------------------------------------------------------
        if (action === "checkUser") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").replace(/\D/g, "");
            
            // Check by Email
            if (email) {
                const emailResult = await docClient.send(new GetCommand({
                    TableName: TABLE_NAME,
                    Key: { email }
                }));
                
                if (emailResult.Item) {
                    return makeResponse(200, {
                        exists: true,
                        field: "email",
                        message: "This email is already registered. Please sign in or use another email."
                    });
                }
            }
            
            // Check by Phone Number
            if (phone && phone.length >= 7) {
                const scanResult = await docClient.send(new ScanCommand({
                    TableName: TABLE_NAME,
                    Limit: 200
                }));
                
                const matched = (scanResult.Items || []).find(item => {
                    const itemPhone = (item.phoneNumber || "").replace(/\D/g, "");
                    return itemPhone && (itemPhone === phone || itemPhone.endsWith(phone) || phone.endsWith(itemPhone));
                });
                
                if (matched) {
                    // If an uncompleted legacy test record has no password, allow registration to adopt it
                    const hasPassword = !!(matched.password || matched.passwordHash);
                    if (hasPassword) {
                        return makeResponse(200, {
                            exists: true,
                            field: "mobile",
                            message: "This mobile number is already registered in AWS. Please sign in with your mobile number or use another number."
                        });
                    }
                }
            }
            
            return makeResponse(200, { exists: false });
        }
        
        // ---------------------------------------------------------------------
        // 4. REGISTER: Stores user and password in AWS DynamoDB
        // ---------------------------------------------------------------------
        if (action === "register") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").trim();
            const password = (body.password || "").trim();
            const passwordHash = (body.passwordHash || "").trim();
            
            const item = {
                email: email,
                phoneNumber: phone,
                userId: body.userId || ("01" + Math.floor(100000 + Math.random() * 900000)),
                name: body.name || "Player",
                tag: body.tag || ("@" + (body.name || "player").toLowerCase().replace(/\s+/g, "_")),
                countryCode: body.countryCode || "+91",
                countryFlag: body.countryFlag || "🇮🇳",
                password: password || passwordHash,
                passwordHash: passwordHash || password,
                level: body.level || 1,
                coins: body.coins || 500,
                trophies: body.trophies || 0,
                createdAt: body.registeredAt || new Date().toISOString(),
                updatedAt: new Date().toISOString()
            };
            
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: item
            }));
            
            return makeResponse(201, {
                success: true,
                message: "User and credentials stored in AWS DynamoDB successfully",
                user: item
            });
        }
        
        // ---------------------------------------------------------------------
        // 5. LIST USERS: Directory of all registered users
        // ---------------------------------------------------------------------
        if (action === "listUsers" || action === "getAllUsers") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_NAME,
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
                createdAt: u.createdAt
            }));
            return makeResponse(200, users);
        }
        
        // ---------------------------------------------------------------------
        // 6. SEARCH USERS
        // ---------------------------------------------------------------------
        if (action === "searchUsers") {
            const raw = (body.query || body.q || "").toLowerCase().trim();
            const cleanQ = raw.replace(/^@/, "");
            if (!cleanQ) {
                return makeResponse(200, []);
            }
            
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_NAME,
                Limit: 100
            }));
            
            const matched = [];
            for (const u of (scanResult.Items || [])) {
                const uId = (u.userId || u.id || "").toLowerCase();
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
                        profilePhoto: u.profilePhoto || null
                    });
                }
            }
            
            return makeResponse(200, matched);
        }
        
        // ---------------------------------------------------------------------
        // 7. RESET PASSWORD
        // ---------------------------------------------------------------------
        if (action === "resetPassword") {
            const email = (body.email || "").toLowerCase().trim();
            const phone = (body.phoneNumber || "").replace(/\D/g, "");
            const newPassword = (body.newPassword || "").trim();
            
            if (!newPassword) {
                return makeResponse(400, { success: false, error: "New password is required." });
            }
            
            let userItem = null;
            if (email) {
                const res = await docClient.send(new GetCommand({
                    TableName: TABLE_NAME,
                    Key: { email }
                }));
                userItem = res.Item;
            }
            
            if (!userItem && phone) {
                const scanRes = await docClient.send(new ScanCommand({
                    TableName: TABLE_NAME,
                    Limit: 200
                }));
                userItem = (scanRes.Items || []).find(u => {
                    const p = (u.phoneNumber || "").replace(/\D/g, "");
                    return p === phone;
                });
            }
            
            if (!userItem) {
                return makeResponse(404, { success: false, error: "Account not found." });
            }
            
            userItem.password = newPassword;
            userItem.passwordHash = newPassword;
            userItem.updatedAt = new Date().toISOString();
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: userItem
            }));
            
            return makeResponse(200, { success: true, message: "Password updated successfully." });
        }
        
        // ---------------------------------------------------------------------
        // 8. DELETE USER
        // ---------------------------------------------------------------------
        if (action === "deleteUser") {
            const email = (body.email || "").toLowerCase().trim();
            if (email) {
                await docClient.send(new DeleteCommand({
                    TableName: TABLE_NAME,
                    Key: { email }
                }));
            }
            return makeResponse(200, { success: true, message: "User deleted from server." });
        }
        
        // ---------------------------------------------------------------------
        // 9. PROFILE PHOTO
        // ---------------------------------------------------------------------
        if (action === "updateProfilePhoto" || action === "deleteProfilePhoto") {
            const email = (body.email || "").toLowerCase().trim();
            const photo = action === "deleteProfilePhoto" ? null : body.profilePhoto;
            
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME,
                Item: { email, profilePhoto: photo, updatedAt: new Date().toISOString() }
            }));
            
            return makeResponse(200, { success: true, message: "Profile photo updated on server" });
        }
        
        // ---------------------------------------------------------------------
        // 10. SONGS
        // ---------------------------------------------------------------------
        if (action === "uploadSong") {
            const song = body.song || {};
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME + "_Songs",
                Item: { ...song, updatedAt: new Date().toISOString() }
            }));
            
            return makeResponse(200, { success: true, message: "Song saved to server" });
        }
        
        if (action === "getUserSongs") {
            const userId = body.userId;
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_NAME + "_Songs",
                FilterExpression: "userId = :uid",
                ExpressionAttributeValues: { ":uid": userId }
            }));
            
            return makeResponse(200, { success: true, songs: scanResult.Items || [] });
        }
        
        // ---------------------------------------------------------------------
        // 11. ROOMS
        // ---------------------------------------------------------------------
        if (action === "getRooms") {
            const scanResult = await docClient.send(new ScanCommand({
                TableName: TABLE_NAME + "_Rooms",
                Limit: 50
            }));
            return makeResponse(200, scanResult.Items || []);
        }
        
        if (action === "createRoom") {
            const room = body.room || body;
            await docClient.send(new PutCommand({
                TableName: TABLE_NAME + "_Rooms",
                Item: { ...room, updatedAt: new Date().toISOString() }
            }));
            return makeResponse(201, { success: true, room });
        }
        
        if (action === "deleteRoom") {
            const roomId = body.roomId || body.id;
            await docClient.send(new DeleteCommand({
                TableName: TABLE_NAME + "_Rooms",
                Key: { id: roomId }
            }));
            return makeResponse(200, { success: true });
        }
        
        return makeResponse(400, { error: "Unknown action: " + action });
    } catch (err) {
        return makeResponse(500, { error: err.message });
    }
};
