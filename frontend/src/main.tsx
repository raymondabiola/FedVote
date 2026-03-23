// Import AppKit config FIRST — initializes the wallet modal
import './config/appkit';

import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { Web3Provider } from './context/Web3Context';
import App from './App';
import './index.css';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <BrowserRouter>
      <Web3Provider>
        <App />
        <Toaster
          position="bottom-right"
          toastOptions={{
            className: 'toast-custom',
            style: { background: '#1a1a2e', color: '#fff', borderRadius: '12px', fontSize: '14px' },
            success: { iconTheme: { primary: '#6C63FF', secondary: '#fff' } },
            error: { iconTheme: { primary: '#ef4444', secondary: '#fff' } },
          }}
        />
      </Web3Provider>
    </BrowserRouter>
  </React.StrictMode>
);
