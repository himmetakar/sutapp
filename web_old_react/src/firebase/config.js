import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  apiKey: 'AIzaSyDqwXjGuKUdu97Xu8tr0hw6I2d0vlOuKRA',
  authDomain: 'sutapp93.firebaseapp.com',
  projectId: 'sutapp93',
  storageBucket: 'sutapp93.firebasestorage.app',
  messagingSenderId: '723710159644',
  appId: '1:723710159644:web:afb8f29df5a9950778a8d9',
  measurementId: 'G-M27Q8S3PQQ'
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export default app;
