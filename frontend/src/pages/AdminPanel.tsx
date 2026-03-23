import React, { useState, useEffect } from 'react';
import { useWeb3 } from '../context/Web3Context';
import { ethers } from 'ethers';
import toast from 'react-hot-toast';

function SectionCard({ title, icon, children, badge }: { title: string; icon: string; children: React.ReactNode; badge?: string }) {
  return (
    <div className="glass-card p-6 mb-6 animate-fade-up">
      <div className="flex items-center gap-3 mb-5">
        <div className="w-10 h-10 rounded-xl bg-brand-50 flex items-center justify-center">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#6C63FF" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d={icon} /></svg>
        </div>
        <h2 className="text-lg font-bold text-gray-900">{title}</h2>
        {badge && <span className="badge badge-brand text-xs">{badge}</span>}
      </div>
      {children}
    </div>
  );
}

export default function AdminPanel() {
  const { account, contracts, roles, refreshRoles, openModal, isConnected } = useWeb3();
  const [submitting, setSubmitting] = useState(false);
  const [activeTab, setActiveTab] = useState('registry');

  const [batchNins, setBatchNins] = useState('');
  const [batchNames, setBatchNames] = useState('');
  const [batchAddresses, setBatchAddresses] = useState('');
  const [removeNin, setRemoveNin] = useState('');
  const [removeAddr, setRemoveAddr] = useState('');
  const [changeNin, setChangeNin] = useState('');
  const [changeAddr, setChangeAddr] = useState('');

  const [newElectionId, setNewElectionId] = useState('');
  const [regFee, setRegFee] = useState('');
  const [approveAcronym, setApproveAcronym] = useState('');
  const [approveElId, setApproveElId] = useState('');
  const [rejectAcronym, setRejectAcronym] = useState('');
  const [rejectElId, setRejectElId] = useState('');
  const [rejectReason, setRejectReason] = useState('');
  const [withdrawTo, setWithdrawTo] = useState('');
  const [withdrawAmt, setWithdrawAmt] = useState('');

  const [elName, setElName] = useState('');
  const [elParties, setElParties] = useState('');
  const [elStart, setElStart] = useState('');
  const [elEnd, setElEnd] = useState('');

  const [newPartyChairman, setNewPartyChairman] = useState('');
  const [newPartyName, setNewPartyName] = useState('');
  const [newBaseIncentive, setNewBaseIncentive] = useState('');
  const [stats, setStats] = useState<any>({});

  useEffect(() => {
    if (!contracts.registry) return;
    (async () => {
      try {
        const [a, v] = await Promise.all([contracts.registry!.totalAuthorizedCitizens(), contracts.registry!.totalRegisteredVoters()]);
        const eId = await contracts.electionBody!.electionId().catch(() => 0n);
        setStats({ totalAuthorized: Number(a), totalVoters: Number(v), currentElectionId: Number(eId) });
      } catch {}
    })();
  }, [contracts]);

  if (!isConnected) return (<div className="max-w-lg mx-auto px-4 py-20 text-center"><div className="glass-card p-10"><h2 className="text-2xl font-bold text-gray-900 mb-4">Connect Wallet</h2><button onClick={openModal} className="btn-primary">Connect Wallet</button></div></div>);
  if (!roles.isAdmin) return (<div className="max-w-lg mx-auto px-4 py-20 text-center"><div className="glass-card p-10"><div className="w-16 h-16 rounded-2xl bg-red-50 flex items-center justify-center mx-auto mb-4"><svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="#ef4444" strokeWidth="2"><path d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/></svg></div><h2 className="text-2xl font-bold text-gray-900 mb-2">Access Denied</h2><p className="text-gray-500">No admin roles.</p></div></div>);

  const tabs: { id: string; label: string }[] = [];
  if (roles.isRegistrationOfficer || roles.isRegistryAdmin) tabs.push({ id: 'registry', label: 'Registry' });
  if (roles.isElectionBodyAdmin) tabs.push({ id: 'electionBody', label: 'Election Body' });
  if (roles.isElectionOfficer || roles.isElectionAdmin) tabs.push({ id: 'election', label: 'Elections' });
  if (roles.isFactoryOwner) tabs.push({ id: 'factory', label: 'Party Factory' });
  if (roles.isIncentivesOwner) tabs.push({ id: 'incentives', label: 'Incentives' });
  if (tabs.length > 0 && !tabs.find(t => t.id === activeTab)) setActiveTab(tabs[0].id);

  const exec = async (label: string, fn: () => Promise<any>) => {
    setSubmitting(true);
    try { toast.loading(`${label}...`, { id: 'admin' }); const tx = await fn(); await tx.wait(); toast.success(`${label} — Success!`, { id: 'admin' }); await refreshRoles(); }
    catch (err: any) { toast.error(err?.reason || `${label} failed`, { id: 'admin' }); }
    finally { setSubmitting(false); }
  };

  const handleAuthorizeBatch = () => {
    const nins = batchNins.split('\n').filter(Boolean).map(n => ethers.keccak256(ethers.solidityPacked(['uint256'], [BigInt(n.trim())])));
    const names = batchNames.split('\n').filter(Boolean).map(n => n.trim());
    const addrs = batchAddresses.split('\n').filter(Boolean).map(a => a.trim());
    if (nins.length !== names.length || nins.length !== addrs.length) { toast.error('All fields must have the same number of entries'); return; }
    exec('Authorizing citizens', () => contracts.registry!.authorizeCitizensByBatch(nins, names, addrs));
  };

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      <div className="mb-8 animate-fade-up">
        <h1 className="text-3xl font-bold text-gray-900">Admin Panel</h1>
        <p className="text-gray-500 mt-1">Manage the FedVote protocol</p>
        <div className="flex flex-wrap gap-2 mt-3">
          {roles.isRegistrationOfficer && <span className="badge badge-brand">Registration Officer</span>}
          {roles.isElectionBodyAdmin && <span className="badge badge-brand">Election Body Admin</span>}
          {roles.isElectionOfficer && <span className="badge badge-brand">Election Officer</span>}
          {roles.isFactoryOwner && <span className="badge badge-brand">Factory Owner</span>}
          {roles.isIncentivesOwner && <span className="badge badge-brand">Incentives Owner</span>}
        </div>
      </div>

      <div className="grid sm:grid-cols-3 gap-4 mb-8 animate-fade-up stagger-1">
        <div className="glass-card p-5"><p className="text-xs text-gray-400 font-semibold uppercase">Authorized Citizens</p><p className="text-2xl font-bold text-gray-900 mt-1">{stats.totalAuthorized?.toLocaleString() || '—'}</p></div>
        <div className="glass-card p-5"><p className="text-xs text-gray-400 font-semibold uppercase">Registered Voters</p><p className="text-2xl font-bold text-gray-900 mt-1">{stats.totalVoters?.toLocaleString() || '—'}</p></div>
        <div className="glass-card p-5"><p className="text-xs text-gray-400 font-semibold uppercase">Current Election ID</p><p className="text-2xl font-bold text-gray-900 mt-1">{stats.currentElectionId || '—'}</p></div>
      </div>

      <div className="flex flex-wrap gap-1 mb-6 p-1 bg-surface-100 rounded-xl w-fit animate-fade-up stagger-2">
        {tabs.map(tab => (<button key={tab.id} onClick={() => setActiveTab(tab.id)} className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${activeTab === tab.id ? 'bg-white text-brand-600 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}>{tab.label}</button>))}
      </div>

      {activeTab === 'registry' && (<>
        <SectionCard title="Authorize Citizens (Batch)" icon="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" badge="Registration Officer">
          <p className="text-sm text-gray-500 mb-4">One NIN, name, and address per line. Same count required.</p>
          <div className="grid md:grid-cols-3 gap-4 mb-4">
            <div><label className="text-xs font-semibold text-gray-600 mb-1 block">NINs</label><textarea value={batchNins} onChange={e => setBatchNins(e.target.value)} className="input-field font-mono text-sm h-32 resize-none" placeholder={"12345678901\n12345678902"} /></div>
            <div><label className="text-xs font-semibold text-gray-600 mb-1 block">Names</label><textarea value={batchNames} onChange={e => setBatchNames(e.target.value)} className="input-field text-sm h-32 resize-none" placeholder={"John\nJane"} /></div>
            <div><label className="text-xs font-semibold text-gray-600 mb-1 block">Addresses</label><textarea value={batchAddresses} onChange={e => setBatchAddresses(e.target.value)} className="input-field font-mono text-sm h-32 resize-none" placeholder={"0x123...\n0x456..."} /></div>
          </div>
          <button onClick={handleAuthorizeBatch} disabled={submitting} className="btn-primary text-sm">{submitting ? 'Processing...' : 'Authorize Batch'}</button>
        </SectionCard>
        <SectionCard title="Manage Voters" icon="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z">
          <div className="grid md:grid-cols-2 gap-6">
            <div className="p-4 rounded-xl bg-surface-100">
              <h4 className="font-semibold text-gray-900 text-sm mb-3">Remove Auth / Deregister</h4>
              <input type="number" value={removeNin} onChange={e => setRemoveNin(e.target.value)} className="input-field text-sm mb-2 font-mono" placeholder="NIN" />
              <input type="text" value={removeAddr} onChange={e => setRemoveAddr(e.target.value)} className="input-field text-sm mb-3 font-mono" placeholder="Address (0x...)" />
              <div className="flex gap-2">
                <button onClick={() => exec('Removing auth', () => contracts.registry!.removeCitizenAuthorization(BigInt(removeNin), removeAddr))} disabled={submitting} className="btn-secondary text-xs">Remove Auth</button>
                <button onClick={() => exec('Deregistering', () => contracts.registry!.deregisterVoter(BigInt(removeNin), removeAddr))} disabled={submitting} className="btn-secondary text-xs !text-red-500 !border-red-200 hover:!bg-red-50">Deregister</button>
              </div>
            </div>
            <div className="p-4 rounded-xl bg-surface-100">
              <h4 className="font-semibold text-gray-900 text-sm mb-3">Change Voter Address</h4>
              <input type="number" value={changeNin} onChange={e => setChangeNin(e.target.value)} className="input-field text-sm mb-2 font-mono" placeholder="NIN" />
              <input type="text" value={changeAddr} onChange={e => setChangeAddr(e.target.value)} className="input-field text-sm mb-3 font-mono" placeholder="New Address (0x...)" />
              <button onClick={() => exec('Changing address', () => contracts.registry!.changeVoterAddress(BigInt(changeNin), changeAddr))} disabled={submitting} className="btn-primary text-xs">Change Address</button>
            </div>
          </div>
        </SectionCard>
      </>)}

      {activeTab === 'electionBody' && (<>
        <SectionCard title="Election Cycle" icon="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z">
          <div className="grid md:grid-cols-2 gap-6">
            <div className="p-4 rounded-xl bg-surface-100"><h4 className="font-semibold text-gray-900 text-sm mb-3">Set New Election ID</h4><input type="number" value={newElectionId} onChange={e => setNewElectionId(e.target.value)} className="input-field text-sm mb-3 font-mono" placeholder="e.g., 2026" /><button onClick={() => exec('Setting election ID', () => contracts.electionBody!.setElectionId(BigInt(newElectionId)))} disabled={submitting} className="btn-primary text-sm">Set Election ID</button></div>
            <div className="p-4 rounded-xl bg-surface-100"><h4 className="font-semibold text-gray-900 text-sm mb-3">Update Registration Fee</h4><input type="text" value={regFee} onChange={e => setRegFee(e.target.value)} className="input-field text-sm mb-3 font-mono" placeholder="Fee in NAT" /><button onClick={() => exec('Updating fee', () => contracts.electionBody!.updateRegFee(ethers.parseEther(regFee)))} disabled={submitting} className="btn-primary text-sm">Update Fee</button></div>
          </div>
        </SectionCard>
        <SectionCard title="Party Applications" icon="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z">
          <div className="grid md:grid-cols-2 gap-6">
            <div className="p-4 rounded-xl bg-emerald-50/50 border border-emerald-100">
              <h4 className="font-semibold text-emerald-800 text-sm mb-3">Approve Party</h4>
              <input type="text" value={approveAcronym} onChange={e => setApproveAcronym(e.target.value)} className="input-field text-sm mb-2" placeholder="Party Acronym" />
              <input type="number" value={approveElId} onChange={e => setApproveElId(e.target.value)} className="input-field text-sm mb-3 font-mono" placeholder="Election ID" />
              <button onClick={() => exec('Approving party', () => contracts.electionBody!.approveAppliedParty(approveAcronym, BigInt(approveElId)))} disabled={submitting} className="btn-primary text-sm !bg-emerald-600 hover:!bg-emerald-700" style={{boxShadow:'0 4px 14px rgba(16,185,129,0.3)'}}>Approve</button>
            </div>
            <div className="p-4 rounded-xl bg-red-50/50 border border-red-100">
              <h4 className="font-semibold text-red-800 text-sm mb-3">Reject Party</h4>
              <input type="text" value={rejectAcronym} onChange={e => setRejectAcronym(e.target.value)} className="input-field text-sm mb-2" placeholder="Party Acronym" />
              <input type="number" value={rejectElId} onChange={e => setRejectElId(e.target.value)} className="input-field text-sm mb-2 font-mono" placeholder="Election ID" />
              <input type="text" value={rejectReason} onChange={e => setRejectReason(e.target.value)} className="input-field text-sm mb-3" placeholder="Reason" />
              <button onClick={() => exec('Rejecting party', () => contracts.electionBody!.rejectPartyRegistration(rejectAcronym, BigInt(rejectElId), rejectReason))} disabled={submitting} className="btn-primary text-sm !bg-red-600 hover:!bg-red-700" style={{boxShadow:'0 4px 14px rgba(239,68,68,0.3)'}}>Reject & Refund</button>
            </div>
          </div>
        </SectionCard>
        <SectionCard title="Withdraw NAT from Election Body" icon="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" badge="Admin">
          <p className="text-sm text-gray-500 mb-4">Withdraw NAT tokens collected from party registration fees.</p>
          <div className="flex flex-wrap gap-3 max-w-xl">
            <input type="text" value={withdrawTo} onChange={e => setWithdrawTo(e.target.value)} className="input-field text-sm font-mono flex-1" placeholder="Recipient address (0x...)" />
            <input type="text" value={withdrawAmt} onChange={e => setWithdrawAmt(e.target.value)} className="input-field text-sm font-mono w-40" placeholder="Amount (NAT)" />
            <button onClick={() => { if (!withdrawTo||!withdrawAmt){toast.error('Fill address and amount');return;} exec('Withdrawing', () => contracts.electionBody!.withdraw(withdrawTo, ethers.parseEther(withdrawAmt))); }} disabled={submitting} className="btn-primary text-sm">{submitting ? 'Withdrawing...' : 'Withdraw'}</button>
          </div>
        </SectionCard>
      </>)}

      {activeTab === 'election' && (<>
        <SectionCard title="Create National Election" icon="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" badge="Election Officer">
          <p className="text-sm text-gray-500 mb-4">Start/end in seconds from now. Parties = comma-separated acronyms.</p>
          <div className="space-y-3 max-w-xl">
            <input type="text" value={elName} onChange={e => setElName(e.target.value)} className="input-field text-sm" placeholder="Election Name" />
            <input type="text" value={elParties} onChange={e => setElParties(e.target.value)} className="input-field text-sm" placeholder="Parties (e.g., APC, PDP, LP)" />
            <div className="grid grid-cols-2 gap-3">
              <input type="number" value={elStart} onChange={e => setElStart(e.target.value)} className="input-field text-sm font-mono" placeholder="Start (s)" />
              <input type="number" value={elEnd} onChange={e => setElEnd(e.target.value)} className="input-field text-sm font-mono" placeholder="End (s)" />
            </div>
            <button onClick={() => { const p=elParties.split(',').map(x=>x.trim()).filter(Boolean); exec('Creating election', () => contracts.election!.createElection(elName, p, BigInt(elStart), BigInt(elEnd))); }} disabled={submitting} className="btn-primary text-sm">{submitting ? 'Creating...' : 'Create Election'}</button>
          </div>
        </SectionCard>
        <SectionCard title="Declare Winner" icon="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z">
          <p className="text-sm text-gray-500 mb-4">Only after election end time.</p>
          <button onClick={() => exec('Declaring winner', () => contracts.election!.declareWinner())} disabled={submitting} className="btn-primary text-sm">{submitting ? 'Processing...' : 'Declare Winner'}</button>
        </SectionCard>
      </>)}

      {activeTab === 'factory' && (
        <SectionCard title="Create Political Party" icon="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5" badge="Factory Owner">
          <div className="space-y-3 max-w-xl">
            <input type="text" value={newPartyChairman} onChange={e => setNewPartyChairman(e.target.value)} className="input-field text-sm font-mono" placeholder="Chairman address (0x...)" />
            <input type="text" value={newPartyName} onChange={e => setNewPartyName(e.target.value)} className="input-field text-sm" placeholder="Party Name" />
            <button onClick={() => exec('Creating party', () => contracts.factory!.createNewPoliticalParty(newPartyChairman, newPartyName, contracts.nationalToken!.target, contracts.electionBody!.target, contracts.registry!.target))} disabled={submitting} className="btn-primary text-sm">{submitting ? 'Deploying...' : 'Create Party'}</button>
          </div>
        </SectionCard>
      )}

      {activeTab === 'incentives' && (
        <SectionCard title="Voter Incentives Settings" icon="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" badge="Owner">
          <p className="text-sm text-gray-500 mb-4">Set base incentive (NAT). 1.3× growth per threshold of 3.</p>
          <div className="flex gap-3 max-w-md">
            <input type="text" value={newBaseIncentive} onChange={e => setNewBaseIncentive(e.target.value)} className="input-field text-sm font-mono flex-1" placeholder="Base amount (e.g., 100)" />
            <button onClick={() => exec('Setting base', () => contracts.voterIncentives!.setBaseIncentives(ethers.parseEther(newBaseIncentive)))} disabled={submitting} className="btn-primary text-sm">{submitting ? 'Setting...' : 'Update'}</button>
          </div>
        </SectionCard>
      )}
    </div>
  );
}