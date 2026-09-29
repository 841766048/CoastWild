// Explicit integration test: creates two temporary anonymous identities, then removes its own notes/users.
import {readFile} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
import {initializeApp, deleteApp} from 'firebase/app';
import {getAuth, signInAnonymously, deleteUser} from 'firebase/auth';
import {getFirestore, doc, setDoc, getDoc, deleteDoc, serverTimestamp, terminate} from 'firebase/firestore';
const plist=await readFile(new URL('../../CoastWild/Resources/GoogleService-Info.plist',import.meta.url),'utf8');
const value=key=>plist.match(new RegExp(`<key>${key}</key>\\s*<string>([^<]+)</string>`))[1];
const config={apiKey:value('API_KEY'),projectId:value('PROJECT_ID'),appId:value('GOOGLE_APP_ID')};
assert.equal(config.projectId,'coast-wild-20260915');
const apps=[initializeApp(config,'notes-check-a'),initializeApp(config,'notes-check-b')];
const users=[]; const databases=[]; let ref;
try {
  for (const app of apps) { users.push((await signInAnonymously(getAuth(app))).user); databases.push(getFirestore(app)); }
  const path=`users/${users[0].uid}/devices/${randomUUID()}/accounts/${'a'.repeat(64)}/notes/${randomUUID()}`;
  ref=doc(databases[0],path);
  await setDoc(ref,{title:'Integration test',body:'Temporary validation only',date:'2026-09-23',isDraft:true,tags:['test'],updatedAt:serverTimestamp(),schemaVersion:1});
  assert.equal((await getDoc(ref)).data().body,'Temporary validation only');
  await assert.rejects(getDoc(doc(databases[1],path)),error=>error.code==='permission-denied');
  await deleteDoc(ref);
  assert.equal((await getDoc(ref)).exists(),false);
  console.log('PASS: anonymous authentication, owner write/read/delete, cross-user read denied');
} finally {
  if(ref) { try { await deleteDoc(ref); } catch(error) { console.error('Test note cleanup:',error.code); } }
  for(const user of users) { try { await deleteUser(user); } catch(error) { console.error('Test user cleanup:',error.code); } }
  for(const db of databases) await terminate(db);
  for(const app of apps) await deleteApp(app);
  console.log('Temporary test notes and anonymous identities cleaned up.');
}
