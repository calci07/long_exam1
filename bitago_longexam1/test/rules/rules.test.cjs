const {readFileSync} = require('node:fs');
const {resolve} = require('node:path');
const {test, before, after, beforeEach} = require('node:test');
const {initializeTestEnvironment, assertFails, assertSucceeds} = require('@firebase/rules-unit-testing');
const {doc, setDoc, getDoc, updateDoc, deleteDoc, collection, getDocs} = require('firebase/firestore');
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
test('unauthenticated users and another user cannot access a profile', async () => {
  await setDoc(doc(owner(),'users/gerald'),profile);
  for (const db of [env.unauthenticatedContext().firestore(), env.authenticatedContext('other').firestore()]) {
    const ref = doc(db,'users/gerald');
    await assertFails(getDoc(ref));
    await assertFails(setDoc(ref,profile));
    await assertFails(deleteDoc(ref));
  }
  await assertFails(getDocs(collection(owner(),'users')));
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
