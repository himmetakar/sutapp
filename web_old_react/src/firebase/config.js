import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyC0-FtYShX4AInMnieL5PHVxmAujWvEhGs',
  authDomain: 'sutapp-9d33c.firebaseapp.com',
  projectId: 'sutapp-9d33c',
  storageBucket: 'sutapp-9d33c.firebasestorage.app',
  messagingSenderId: '216356501452',
  appId: '1:216356501452:web:a0f72b9c489b63b5dd4f69'
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export default app;
