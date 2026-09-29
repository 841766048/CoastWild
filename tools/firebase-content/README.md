# Firebase public content publisher

This dependency-free Node tool validates and packages only the public catalog and the images it references. It never scans or copies the whole project, removes old releases, deploys, or stores credentials.

## Build and test

From this directory:

```sh
npm test
npm run build -- /absolute/path/to/reviewed/catalog.json
```

The build adds a content-addressed release under `.firebase-public/content/<version>/images/` and writes the exact `publicCatalog/current` document payload to `.firebase-content/manifest.json`. Both generated roots are gitignored. Repeating a build with identical catalog and image bytes produces the same version and leaves previous version directories intact.

Native V1 has no bundled catalog. Supply an explicitly reviewed source, such as the second version's `CoastWild/Resources/catalog.json`; the test fixture under `Tests/Fixtures` is only for automated validation and is not a publishing default. Existing hosted releases are unchanged by the native capability split.

## Reviewed release sequence

Do not combine these commands into an unattended publish. First review the manifest, then deploy only Hosting:

```sh
npx -y firebase-tools@latest deploy --only hosting --project coast-wild-20260915
```

After Hosting succeeds, publish the current document. The command fetches every hosted image, requires HTTP 200, verifies its SHA-256, and only then writes `publicCatalog/current` through the Firestore REST API:

```sh
npm run publish -- --base-url https://coast-wild-20260915.web.app
```

Authentication is resolved without logging or persisting credentials by this tool, in this order:

1. `GOOGLE_OAUTH_ACCESS_TOKEN` in the environment.
2. Application Default Credentials through `gcloud auth application-default print-access-token`.
3. An existing Firebase CLI login when `NODE_PATH` points to a reviewed `firebase-tools` installation's `node_modules` directory. For the currently verified local npx installation:

```sh
NODE_PATH=/Users/zhanghaibin/.npm/_npx/ba4f1959e38407b5/node_modules npm run publish -- --base-url https://coast-wild-20260915.web.app
```

The npx cache path is machine-specific and may change; verify that it contains `firebase-tools/lib/requireAuth.js` before reuse. Never paste tokens into command arguments or files.
