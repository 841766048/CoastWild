// Run after publishing. Uses one temporary identity and never writes private user data.
import {readFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, signInAnonymously, deleteUser} from 'firebase/auth';
import {getFirestore, doc, getDoc, setDoc, getDocs, collection, terminate} from 'firebase/firestore';
const plist = await readFile(new URL('../../CoastWild/Resources/GoogleService-Info.plist', import.meta.url), 'utf8');
const value = key => plist.match(new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`))[1];
const config = {apiKey:value('API_KEY'), projectId:value('PROJECT_ID'), appId:value('GOOGLE_APP_ID')};
assert.equal(config.projectId, 'coast-wild-20260915');
const app = initializeApp(config, 'public-content-check');
const db = getFirestore(app);
let user;
try {
  const ref = doc(db, 'publicCatalog/current');
  await assert.rejects(getDoc(ref), error => error.code === 'permission-denied');
  user = (await signInAnonymously(getAuth(app))).user;
  const snapshot = await getDoc(ref);
  assert.equal(snapshot.exists(), true);
  const remote = snapshot.data();
  const local = JSON.parse(await readFile(new URL('../../.firebase-content/manifest.json', import.meta.url), 'utf8'));
  assert.deepEqual(remote, local);
  await assert.rejects(setDoc(ref, remote), error => error.code === 'permission-denied');
  await assert.rejects(getDocs(collection(db, 'publicCatalog')), error => error.code === 'permission-denied');
  const catalog = JSON.parse(remote.catalogJSON);
  console.log(`PASS: version=${remote.version}; items=${catalog.items.length}; lessons=${catalog.lessons.length}; images=${remote.images.length}; guest/list/client-write denied.`);
} finally {
  if (user) await deleteUser(user);
  await terminate(db);
  await deleteApp(app);
}
