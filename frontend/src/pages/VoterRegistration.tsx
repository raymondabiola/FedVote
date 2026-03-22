import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useWeb3 } from '../context/Web3Context';
import toast from 'react-hot-toast';

export default function VoterRegistration() {
  const { account, contracts, roles, refreshRoles, openModal, isConnected } = useWeb3();
  const navigate = useNavigate();
  const [nin, setNin] = useState('');
  const [name, setName] = useState('');
  const [submitting, setSubmitting] = useState(false);

  if (!isConnected) {
    return (
      <div className="max-w-lg mx-auto px-4 py-20 text-center">
        <div className="glass-card p-10">
          <div className="w-16 h-16 rounded-2xl bg-brand-50 flex items-center justify-center mx-auto mb-5">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#6C63FF" strokeWidth="2"><rect x="2" y="6" width="20" height="12" rx="2" /><path d="M22 10H18a2 2 0 000 4h4" /></svg>
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Connect Your Wallet</h2>
          <p className="text-gray-500 mb-6">You need to connect your wallet to register as a voter.</p>
          <button onClick={openModal} className="btn-primary">Connect Wallet</button>
        </div>
      </div>
    );
  }

  if (roles.isRegisteredVoter) {
    return (
      <div className="max-w-lg mx-auto px-4 py-20 text-center">
        <div className="glass-card p-10">
          <div className="w-16 h-16 rounded-2xl bg-emerald-50 flex items-center justify-center mx-auto mb-5">
            <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="2"><path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
          </div>
          <h2 className="text-2xl font-bold text-gray-900 mb-2">Already Registered</h2>
          <p className="text-gray-500 mb-6">You are already registered as a voter on-chain.</p>
          <button onClick={() => navigate('/dashboard')} className="btn-primary">Go to Dashboard</button>
        </div>
      </div>
    );
  }

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!nin.trim() || !name.trim()) { toast.error('Please fill in both fields'); return; }
    setSubmitting(true);
    try {
      const tx = await contracts.registry!.voterSelfRegister(BigInt(nin), name);
      toast.loading('Registering on-chain...', { id: 'register' });
      await tx.wait();
      toast.success('Successfully registered as a voter!', { id: 'register' });
      await refreshRoles();
      navigate('/dashboard');
    } catch (err: any) {
      const reason = err?.reason || err?.data?.message || err?.message || 'Registration failed';
      toast.error(
        reason.includes('InvalidNIN') ? 'Your NIN is not authorized. Visit a Registration Office.' :
        reason.includes('NINNotFoundInDataBase') ? 'Your NIN does not match this wallet address.' :
        reason.includes('InvalidGovernmentRegisteredFirstName') ? 'Name does not match authorized records.' :
        reason.includes('CitizenCannotRegisterTwice') ? 'This NIN is already registered.' :
        `Registration failed: ${reason}`, { id: 'register' }
      );
    } finally { setSubmitting(false); }
  };

  return (
    <div className="max-w-2xl mx-auto px-4 py-12">
      <div className="text-center mb-8 animate-fade-up">
        <span className="badge badge-brand mb-3">Step 2 of 4</span>
        <h1 className="text-3xl font-bold text-gray-900 mb-2">Register as a Voter</h1>
        <p className="text-gray-500 max-w-md mx-auto">Enter your National Identification Number and government-registered first name to register on-chain.</p>
      </div>

      {!roles.isAuthorizedCitizen && (
        <div className="glass-card p-6 mb-6 border-l-4 border-amber-400 animate-fade-up stagger-1">
          <div className="flex gap-3">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2" className="flex-shrink-0 mt-0.5"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z" /><line x1="12" y1="9" x2="12" y2="13" /><line x1="12" y1="17" x2="12.01" y2="17" /></svg>
            <div>
              <p className="font-semibold text-gray-900 text-sm">Address Not Authorized</p>
              <p className="text-sm text-gray-500 mt-1">Your wallet address has not been authorized by a Registration Office yet. Please visit a registration office with your NIN, name, and wallet address to get authorized first.</p>
            </div>
          </div>
        </div>
      )}

      <form onSubmit={handleRegister} className="glass-card p-8 animate-fade-up stagger-2">
        <div className="space-y-5">
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-2">National Identification Number (NIN)</label>
            <input type="number" value={nin} onChange={(e) => setNin(e.target.value)} className="input-field font-mono" placeholder="Enter your 11-digit NIN" required />
            <p className="text-xs text-gray-400 mt-1.5">Your NIN will be hashed on-chain — it is never stored in plain text.</p>
          </div>
          <div>
            <label className="block text-sm font-semibold text-gray-700 mb-2">Government-Registered First Name</label>
            <input type="text" value={name} onChange={(e) => setName(e.target.value)} className="input-field" placeholder="Enter your first name exactly as registered" required />
            <p className="text-xs text-gray-400 mt-1.5">Must match exactly what was submitted to the Registration Office.</p>
          </div>
          <div className="pt-2">
            <div className="flex items-start gap-3 p-4 rounded-xl bg-surface-100 mb-5">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#6C63FF" strokeWidth="2" className="flex-shrink-0 mt-0.5"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" /></svg>
              <p className="text-xs text-gray-500">By registering, your NIN is cryptographically hashed and linked to your wallet. Even if someone knows your NIN and name, they cannot register without your wallet's private key.</p>
            </div>
            <button type="submit" disabled={submitting || !roles.isAuthorizedCitizen} className="btn-primary w-full text-base !py-3.5">
              {submitting ? (
                <span className="flex items-center gap-2">
                  <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" /><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" /></svg>
                  Registering On-Chain...
                </span>
              ) : 'Register as Voter'}
            </button>
          </div>
        </div>
      </form>
    </div>
  );
}