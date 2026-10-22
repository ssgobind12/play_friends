# Play Friends — Production Trusted Backend Service

This service handles security-sensitive operations for the Play Friends Flutter application:
- **Scrypt Password Hashing**: Passwords are hashed using scrypt with unique per-user 16-byte cryptographically secure random salts.
- **Server-Side OTP Lifecycle**: Cryptographically secure 6-digit OTP generation, 5-minute strict expiry, max 3 failed attempt lockout, single-use token consumption, and 60-second cooldown.
- **Privileged Email Dispatch**: Brevo transactional email sending via backend REST API using securely loaded environment variables (`BREVO_API_KEY`).
- **Role Assignment & Authorization**: Administrator privileges (`role: 'admin'`) can only be granted by the server; user-controlled form data and local storage tampering cannot elevate privileges.
- **Atomic Data Uniqueness**: Email and phone number uniqueness are checked atomically on the server.

---

## Deployment Options

### Option 1: Docker / Node.js Server (EC2, Render, Fly.io, Railway)

1. Navigate to the `backend/` directory:
   ```bash
   cd backend
   npm install
   ```

2. Configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your real BREVO_API_KEY and SESSION_SECRET
   ```

3. Start the server:
   ```bash
   npm start
   ```

### Option 2: AWS Lambda + API Gateway (Serverless)

Deploy `backend/lambda_handler.js` to AWS Lambda:
- **Runtime**: Node.js 20.x
- **Handler**: `lambda_handler.handler`
- **Environment Variables**:
  - `TABLE_NAME`: `PlayFriends_Users`
  - `BREVO_API_KEY`: *(Your private Brevo API key)*
  - `BREVO_SENDER_EMAIL`: `noreply@ssgobind.space`
  - `BREVO_SENDER_NAME`: `Play Friends`
- **IAM Role**: Requires `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:ScanCommand` permissions on `PlayFriends_Users` and `PlayFriends_Users_Songs`.
