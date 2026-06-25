/**
 * Creates a Twilio Verify service for SMS OTP. Run from functions/ after
 * setting TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN in .env
 *
 * Usage: node scripts/setup_twilio_verify.js
 */
const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "..", ".env") });

const twilio = require("twilio");

const accountSid = process.env.TWILIO_ACCOUNT_SID;
const authToken = process.env.TWILIO_AUTH_TOKEN;

if (!accountSid || !authToken) {
  console.error("Set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN in functions/.env");
  process.exit(1);
}

async function main() {
  const client = twilio(accountSid, authToken);
  const service = await client.verify.v2.services.create({
    friendlyName: "Hello Tuk-Tuk SMS OTP",
    codeLength: 6,
    lookupEnabled: true,
  });

  console.log("\nTwilio Verify service created.");
  console.log(`Service SID: ${service.sid}`);
  console.log("\nAdd to functions/.env:");
  console.log(`TWILIO_VERIFY_SERVICE_SID=${service.sid}`);
  console.log("\nThen deploy:");
  console.log(
    "firebase deploy --only functions:sendWhatsAppOtp,functions:verifyWhatsAppOtp",
  );
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
