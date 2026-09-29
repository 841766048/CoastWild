import { readFile } from 'node:fs/promises';
import { before, after, test } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, getDocs, collection, deleteDoc, updateDoc, serverTimestamp, writeBatch, deleteField } from 'firebase/firestore';

let env;
const path = `users/alice/devices/AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE/accounts/${'a'.repeat(64)}/notes/note-1`;
const data = () => ({title:'My note', body:'Private text', date:'2026-09-23', isDraft:true, tags:['surf'], updatedAt:serverTimestamp(), schemaVersion:1});
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-coast-notes', firestore:{rules:await readFile(new URL('../../firestore.rules', import.meta.url),'utf8')}});
});
after(async () => { await env?.cleanup(); });
test('image backup batch, owner-only restore, removal and delete cascade', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const note = doc(db,path), image = doc(db,path+'/images/photo-a');
  const payload = () => ({base64:'/9j/2Q==', bytes:4, sha256:'a'.repeat(64), width:10, height:20,
    mimeType:'image/jpeg', schemaVersion:1, updatedAt:serverTimestamp()});
  await assertFails(setDoc(image,payload())); // no parent reference
  const batch = writeBatch(db);
  batch.set(note,{...data(),schemaVersion:2,photoIDs:['photo-a']});
  batch.set(image,payload());
  await assertSucceeds(batch.commit());
  await assertSucceeds(getDoc(image));
  await assertSucceeds(getDocs(collection(db,path+'/images')));
  for (const context of [env.authenticatedContext('bob'),env.unauthenticatedContext()]) {
    const other = context.firestore();
    await assertFails(getDoc(doc(other,image.path)));
    await assertFails(getDocs(collection(other,path+'/images')));
    await assertFails(setDoc(doc(other,image.path),payload()));
    await assertFails(updateDoc(doc(other,image.path),{width:1}));
    await assertFails(deleteDoc(doc(other,image.path)));
  }
  for (const change of [{base64:'x'.repeat(273069)},{bytes:204801},{width:1601},{height:0},
      {mimeType:'text/html'},{schemaVersion:2},{sha256:'bad'},{base64:42},{admin:true},
      {updatedAt:new Date(0)}]) {
    await assertFails(setDoc(image,{...payload(),...change}));
    await assertFails(updateDoc(image,{...change,...('updatedAt' in change?{}:{updatedAt:serverTimestamp()})}));
  }
  await assertFails(updateDoc(image,{base64:deleteField(),updatedAt:serverTimestamp()}));
  for (const ids of [Array(13).fill('a'), ['../secret'],[7],['a','a']]) {
    await assertFails(setDoc(note,{...data(),schemaVersion:2,photoIDs:ids}));
  }
  const remove = writeBatch(db);
  remove.set(note,{...data(),schemaVersion:2,photoIDs:[]}); remove.delete(image);
  await assertSucceeds(remove.commit());
  const restore = writeBatch(db);
  restore.set(note,{...data(),schemaVersion:2,photoIDs:['photo-a']}); restore.set(image,payload());
  await assertSucceeds(restore.commit());
  const cleanup = writeBatch(db); cleanup.delete(image); cleanup.delete(note);
  await assertSucceeds(cleanup.commit());
  if ((await getDoc(image)).exists()) throw new Error('image survived cleanup');
});
test('published catalog is readable to authenticated clients only and never client-writable', async () => {
  await env.withSecurityRulesDisabled(async context => {
    await setDoc(doc(context.firestore(), 'publicCatalog/current'), {schemaVersion:1, version:'a'.repeat(64), catalogJSON:'{}', images:[]});
    await setDoc(doc(context.firestore(), 'publicCatalog/draft'), {private:'not published'});
  });
  const db = env.authenticatedContext('reader').firestore();
  await assertSucceeds(getDoc(doc(db, 'publicCatalog/current')));
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'publicCatalog/current')));
  await assertFails(getDoc(doc(db, 'publicCatalog/draft')));
  await assertFails(getDocs(collection(db, 'publicCatalog')));
  await assertFails(setDoc(doc(db, 'publicCatalog/current'), {admin:true}));
  await assertFails(updateDoc(doc(db, 'publicCatalog/current'), {catalogJSON:'poison'}));
  await assertFails(deleteDoc(doc(db, 'publicCatalog/current')));
  await assertFails(setDoc(doc(db, 'publicCatalog/draft'), {published:true}));
});
test('twelve-image atomic backup and a fresh client can recover the same identity', async () => {
  const db = env.authenticatedContext('alice').firestore();
  const target = path.replace('note-1', 'note-twelve');
  const ids = Array.from({length:12}, (_,i) => 'image-'+i);
  const batch = writeBatch(db);
  batch.set(doc(db,target),{...data(),schemaVersion:2,photoIDs:ids});
  for (const id of ids) batch.set(doc(db,target+'/images/'+id), {
    base64:'/9j/2Q==', bytes:4, sha256:'a'.repeat(64),width:10,height:20,
    mimeType:'image/jpeg',schemaVersion:1,updatedAt:serverTimestamp()
  });
  await assertSucceeds(batch.commit());
  const fresh = env.authenticatedContext('alice').firestore();
  const recovered = (await assertSucceeds(getDoc(doc(fresh,target)))).data();
  if (JSON.stringify(recovered.photoIDs) !== JSON.stringify(ids)) throw new Error('photo order changed');
  for (const id of recovered.photoIDs) await assertSucceeds(getDoc(doc(fresh,target+'/images/'+id)));
  const replacement = env.authenticatedContext('replacement-anonymous-uid').firestore();
  await assertFails(getDoc(doc(replacement,target)));
});
test('owner can create, read, list, update and delete; other UID and anonymous HTTP cannot', async () => {
  const alice = env.authenticatedContext('alice', {firebase:{sign_in_provider:'anonymous'}}).firestore();
  const bob = env.authenticatedContext('bob').firestore();
  const guest = env.unauthenticatedContext().firestore();
  await assertSucceeds(setDoc(doc(alice,path),data()));
  await assertSucceeds(getDoc(doc(alice,path)));
  await assertSucceeds(getDocs(collection(alice,path.split('/').slice(0,-1).join('/'))));
  for(const db of [bob,guest]) {
    await assertFails(getDoc(doc(db,path)));
    await assertFails(getDocs(collection(db,path.split('/').slice(0,-1).join('/'))));
    await assertFails(setDoc(doc(db,path),data()));
    await assertFails(deleteDoc(doc(db,path)));
  }
  await assertSucceeds(updateDoc(doc(alice,path),{body:'Edited',updatedAt:serverTimestamp()}));
  await assertSucceeds(deleteDoc(doc(alice,path)));
});
test('reject malformed create and update payloads', async () => {
  const db=env.authenticatedContext('alice').firestore();
  const ref=doc(db,path);
  const attacks=[
    {title:'x'.repeat(81)}, {body:'x'.repeat(10001)}, {body:4}, {isDraft:'true'},
    {tags:['x'.repeat(13)]}, {tags:[1]}, {tags:Array(6).fill('a')},
    {date:'bad'}, {updatedAt:new Date(0)}, {schemaVersion:2},
    {ownerUID:'bob'}, {photos:['private.jpg']}, {token:'secret'}, {admin:true}
  ];
  for(const attack of attacks) {
    await assertFails(setDoc(ref,{...data(),...attack}));
    await assertSucceeds(setDoc(ref,data()));
    await assertFails(updateDoc(ref,{...attack, ...(Object.hasOwn(attack,'updatedAt') ? {} : {updatedAt:serverTimestamp()})}));
  }
  const incomplete=data(); delete incomplete.body;
  await assertFails(setDoc(ref,incomplete));
  await assertFails(setDoc(doc(db,'users/alice'),{admin:true}));
  await assertFails(setDoc(doc(db,path+'/private/child'),data()));
  await assertFails(getDoc(doc(db,'users/bob')));
});
