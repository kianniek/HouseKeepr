import React from 'react';
import { createRoot } from 'react-dom/client';

const rootElem = document.getElementById('root');
const App = () => <h1>Hello, Smart Household Agenda!</h1>;

createRoot(rootElem).render(<App />);
