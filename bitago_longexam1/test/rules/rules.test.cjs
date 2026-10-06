const {readFileSync} = require('node:fs');
const {resolve} = require('node:path');
const {test, before, after, beforeEach} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, updateDoc, deleteDoc, collection, getDocs, serverTimestamp, writeBatch} = require('firebase/firestore');
let env;
const profile = {fName:'Gerald', lName:'Bitago', age:22, contactNo:'09123456789',
  username:'geraldb', emailAddress:'gerald@example.com'};
before(async () => {
  env = await initializeTestEnvironment({projectId:'demo-bitago', firestore:{
    host:'127.0.0.1', port:8088, rules:readFileSync(resolve(__dirname,'../../firestore.rules'),'utf8')}});
});
after(async () => {if (env) await env.cleanup();});
beforeEach(async () => {await env.clearFirestore();});
function owner() {return env.authenticatedContext('gerald', {email:'gerald@example.com'}).firestore();}
test('owner can create, read, update username and delete own profile', async () => {
  const ref = doc(owner(),'users/gerald');
  await assertSucceeds(setDoc(ref,profile));
  await assertSucceeds(getDoc(ref));
  await assertSucceeds(updateDoc(ref,{username:'gerald_updated'}));
  await assertSucceeds(deleteDoc(ref));
});
test('signed-in users can discover profiles but only owners can change them', async () => {
  await setDoc(doc(owner(),'users/gerald'),profile);
  for (const db of [env.unauthenticatedContext().firestore(), env.authenticatedContext('other').firestore()]) {
    const ref = doc(db,'users/gerald');
    await assertFails(setDoc(ref,profile));
    await assertFails(deleteDoc(ref));
  }
  await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(),'users/gerald')));
  await assertFails(getDocs(collection(env.unauthenticatedContext().firestore(),'users')));
  await assertSucceeds(getDocs(collection(owner(),'users')));
});

function person(uid) {return env.authenticatedContext(uid, {email:`${uid}@example.com`}).firestore();}
async function seedChat() {
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    for (const uid of ['alice','bob','eve']) await setDoc(doc(db,`users/${uid}`), {...profile,emailAddress:`${uid}@example.com`});
  });
}
function message() {return {senderId:'alice',senderEmail:'alice@example.com',receiverId:'bob',message:'Hello',timestamp:serverTimestamp(),deliveredAt:null,seenAt:null};}
async function send(db = person('alice'), data = message()) {
  const batch = writeBatch(db);
  batch.set(doc(db,'chat_rooms/alice_bob'),{members:['alice','bob']},{merge:true});
  batch.set(doc(db,'chat_rooms/alice_bob/messages/hello'),data);
  return batch.commit();
}
test('participants can send and read; outsiders and anonymous users cannot', async () => {
  await seedChat();
  await assertSucceeds(send());
  await assertSucceeds(getDocs(collection(person('bob'),'chat_rooms/alice_bob/messages')));
  for (const db of [person('eve'),env.unauthenticatedContext().firestore()]) {
    await assertFails(getDoc(doc(db,'chat_rooms/alice_bob')));
    await assertFails(getDocs(collection(db,'chat_rooms/alice_bob/messages')));
    await assertFails(send(db));
  }
  await assertFails(updateDoc(doc(person('alice'),'chat_rooms/alice_bob'),{members:['alice','eve']}));
});
test('only receiver can acknowledge; message and existing receipts are immutable', async () => {
  await seedChat();
  await send();
  const alice = doc(person('alice'),'chat_rooms/alice_bob/messages/hello');
  const bob = doc(person('bob'),'chat_rooms/alice_bob/messages/hello');
  await assertFails(updateDoc(alice,{deliveredAt:serverTimestamp()}));
  await assertFails(updateDoc(bob,{seenAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(bob,{deliveredAt:serverTimestamp()}));
  await assertSucceeds(updateDoc(bob,{seenAt:serverTimestamp()}));
  await assertFails(updateDoc(bob,{seenAt:null}));
  await assertFails(updateDoc(bob,{message:'tampered'}));
  await assertFails(deleteDoc(alice));
});
test('spoofing, empty/oversized messages, forged receipts and missing recipients fail', async () => {
  await seedChat();
  for (const patch of [{senderId:'bob'}, {senderEmail:'bob@example.com'}, {receiverId:'eve'}, {message:''}, {message:'x'.repeat(4001)}, {seenAt:serverTimestamp()}, {timestamp:null}]) {
    await assertFails(send(person('alice'),{...message(),...patch}));
  }
  await assertFails(setDoc(doc(person('alice'),'chat_rooms/alice_missing'),{members:['alice','missing']}));
  await assertFails(setDoc(doc(person('alice'),'chat_rooms/alice_alice'),{members:['alice','alice']}));
});
test('invalid profiles, password storage and identity edits are rejected', async () => {
  const ref = doc(owner(),'users/gerald');
  for (const bad of [{username:'incomplete'}, {...profile,age:-1},
    {...profile,password:'Example123!'}, {...profile,emailAddress:'other@example.com'},
    {...profile,username:'x'}]) await assertFails(setDoc(ref,bad));
  await setDoc(ref,profile);
  await assertFails(updateDoc(ref,{emailAddress:'other@example.com'}));
  await assertFails(updateDoc(ref,{age:23}));
});
