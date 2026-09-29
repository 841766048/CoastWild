import { execFile } from "node:child_process";
import { promisify } from "node:util";

const defaultExecute = promisify(execFile);

export async function getAdminAccessToken({ env = process.env, execute = defaultExecute, projectRoot = process.cwd() } = {}) {
  if (env.GOOGLE_OAUTH_ACCESS_TOKEN) return env.GOOGLE_OAUTH_ACCESS_TOKEN;
  try {
    const result = await execute("gcloud", ["auth", "application-default", "print-access-token"], { env });
    if (result.stdout.trim()) return result.stdout.trim();
  } catch {}
  if (env.NODE_PATH) {
    const script = `
      const auth = require("firebase-tools/lib/auth");
      const api = require("firebase-tools/lib/apiv2");
      const { requireAuth } = require("firebase-tools/lib/requireAuth");
      (async () => {
        const account = auth.getProjectDefaultAccount(process.argv[1]);
        if (!account) throw new Error("No Firebase CLI login found");
        const options = { project: "coast-wild-20260915" };
        auth.setActiveAccount(options, account);
        await requireAuth(options, true);
        process.stdout.write(await api.getAccessToken());
      })().catch((error) => { process.stderr.write(error.message); process.exit(1); });`;
    try {
      const result = await execute(process.execPath, ["-e", script, projectRoot], { env });
      if (result.stdout.trim()) return result.stdout.trim();
    } catch {}
  }
  throw new Error("Set GOOGLE_OAUTH_ACCESS_TOKEN, configure gcloud ADC, or set NODE_PATH to a verified firebase-tools node_modules directory with an active Firebase CLI login");
}
