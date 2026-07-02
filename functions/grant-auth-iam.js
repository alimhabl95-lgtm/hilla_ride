const { GoogleAuth } = require("google-auth-library");

const PROJECT_ID = "hello-tiktok-57dc5";
const MEMBERS = [
  "serviceAccount:hello-tiktok-57dc5@appspot.gserviceaccount.com",
  "serviceAccount:firebase-adminsdk-fbsvc@hello-tiktok-57dc5.iam.gserviceaccount.com",
];
const ROLES = [
  "roles/firebaseauth.admin",
  "roles/datastore.user",
  "roles/firebase.admin",
  "roles/storage.objectAdmin",
];

async function main() {
  const auth = new GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const client = await auth.getClient();
  const baseUrl = `https://cloudresourcemanager.googleapis.com/v1/projects/${PROJECT_ID}`;

  const policyResponse = await client.request({
    url: `${baseUrl}:getIamPolicy`,
    method: "POST",
    data: {},
  });
  const policy = policyResponse.data;

  for (const role of ROLES) {
    const binding = policy.bindings.find((entry) => entry.role === role);
    if (binding) {
      for (const member of MEMBERS) {
        if (!binding.members.includes(member)) {
          binding.members.push(member);
        }
      }
    } else {
      policy.bindings.push({ role, members: [...MEMBERS] });
    }
  }

  await client.request({
    url: `${baseUrl}:setIamPolicy`,
    method: "POST",
    data: { policy },
  });

  console.log("IAM roles granted:", ROLES.join(", "));
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
