import React, { useState, useEffect, useCallback } from 'react';
import { Link } from 'react-router-dom';
import { useWeb3 } from '../context/Web3Context';
import { ethers } from 'ethers';
import toast from 'react-hot-toast';

export default function PartyPortal() {
  const { account, contracts, roles, userParty, getPartyContract, refreshRoles, openModal, isConnected } = useWeb3();
  const [partyData, setPartyData] = useState<any>(null);
  const [candidates, setCandidates] = useState<any[]>([]);
  const [electionDetails, setElectionDetails] = useState<any>(null);
  const [memberInfo, setMemberInfo] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [hasVotedPrimary, setHasVotedPrimary] = useState(false);
  const [countdown, setCountdown] = useState('');
  const [showCandForm, setShowCandForm] = useState(false);
  const [candName, setCandName] = useState('');
  const [candNin, setCandNin] = useState('');
  const [showCreateElection, setShowCreateElection] = useState(false);
  const [elStartTime, setElStartTime] = useState('');
  const [elEndTime, setElEndTime] = useState('');
  const [elCandDeadline, setElCandDeadline] = useState('');
  const [showSetMemberFee, setShowSetMemberFee] = useState(false);
  const [newMemberFee, setNewMemberFee] = useState('');
  const [showSetCandFee, setShowSetCandFee] = useState(false);
  const [newCandFee, setNewCandFee] = useState('');
  const [showRemoveMember, setShowRemoveMember] = useState(false);
  const [rmMemberAddr, setRmMemberAddr] = useState('');
  const [rmMemberNin, setRmMemberNin] = useState('');
  const [showRemoveCandidate, setShowRemoveCandidate] = useState(false);
  const [rmCandElId, setRmCandElId] = useState('');
  const [rmCandId, setRmCandId] = useState('');
  const [rmCandAddr, setRmCandAddr] = useState('');

  const fetchPartyData = useCallback(async () => {
    if (!userParty?.address || !account) return;
    setLoading(true);
    try {
      const pc = getPartyContract(userParty.address);
      const [name, chairman, memberFee, candFee, elId] = await Promise.all([pc.partyName(), pc.chairman(), pc.membershipFee().catch(() => 0n), pc.candidacyFee().catch(() => 0n), pc.electionId().catch(() => 0n)]);
      setPartyData({ name, chairman, membershipFee: ethers.formatEther(memberFee), candidacyFee: ethers.formatEther(candFee), electionId: Number(elId) });
      try { const mem = await pc.getPartyMember(account); if (mem.walletAddress !== ethers.ZeroAddress) setMemberInfo({ id: Number(mem.id), name: mem.name, party: mem.party, hasPaid: mem.hasPaidForMembership }); } catch {}
      const eid = Number(elId);
      if (eid > 0) {
        try { const elData = await pc.checkElectionStatus(elId); setElectionDetails({ id: Number(elData.id), partyName: elData.partyName, startTime: Number(elData.startTime), endTime: Number(elData.endTime), candidateRegDeadline: Number(elData.candidateRegDeadline), winnerIndex: Number(elData.winnerCandidateIndex) }); try { setHasVotedPrimary(await pc.hasVoted(elId, account)); } catch { setHasVotedPrimary(false); } } catch {}
        try { const cl = await pc.getAllPartyCandidates(elId); setCandidates(cl.map((c: any) => ({ id: Number(c.id), name: c.name, party: c.party, voteCount: Number(c.voteCount), walletAddress: c.walletAddress }))); } catch { setCandidates([]); }
      }
    } catch (e) { console.log('Party data error:', e); }
    setLoading(false);
  }, [userParty, account, getPartyContract]);

  useEffect(() => { fetchPartyData(); }, [fetchPartyData]);

  useEffect(() => {
    if (!electionDetails) return;
    const interval = setInterval(() => {
      const now = Math.floor(Date.now() / 1000); let target: number, label: string;
      if (now < electionDetails.candidateRegDeadline) { target = electionDetails.candidateRegDeadline; label = 'Registration closes in'; }
      else if (now < electionDetails.startTime) { target = electionDetails.startTime; label = 'Voting starts in'; }
      else if (now < electionDetails.endTime) { target = electionDetails.endTime; label = 'Voting ends in'; }
      else { setCountdown('Primary election ended'); clearInterval(interval); return; }
      const diff = target - now;
      setCountdown(`${label} ${Math.floor(diff / 3600)}h ${Math.floor((diff % 3600) / 60)}m ${diff % 60}s`);
    }, 1000);
    return () => clearInterval(interval);
  }, [electionDetails]);

  const exec = async (label: string, fn: () => Promise<any>, toastId: string) => {
    setSubmitting(true);
    try { toast.loading(`${label}...`, { id: toastId }); const tx = await fn(); await tx.wait(); toast.success(`${label} done!`, { id: toastId }); fetchPartyData(); }
    catch (err: any) { toast.error(err?.reason || `${label} failed`, { id: toastId }); }
    finally { setSubmitting(false); }
  };

  const handlePayCandidacy = async () => { setSubmitting(true); try { const pc = getPartyContract(userParty!.address); const fee = await pc.candidacyFee(); toast.loading('Approving...', { id: 'cand' }); await (await contracts.nationalToken!.approve(userParty!.address, fee)).wait(); toast.loading('Paying...', { id: 'cand' }); await (await pc.payForCandidateship()).wait(); toast.success('Paid!', { id: 'cand' }); } catch (err: any) { toast.error(err?.reason || 'Failed', { id: 'cand' }); } finally { setSubmitting(false); } };
  const handleRegisterCandidate = () => { if (!candName || !candNin) { toast.error('Fill fields'); return; } exec('Registering candidate', () => getPartyContract(userParty!.address).registerCandidate(candName, BigInt(candNin)), 'regcand'); };
  const handleVotePrimary = (candidateId: number) => { setSubmitting(true); exec('Casting vote', () => getPartyContract(userParty!.address).voteforPrimaryElection(candidateId, partyData.electionId), 'pvote').then(() => setHasVotedPrimary(true)); };
  const handleSetElectionId = () => exec('Syncing election ID', () => getPartyContract(userParty!.address).setElectionId(), 'seid');
  const handleCreatePrimaryElection = () => { if (!elStartTime || !elEndTime || !elCandDeadline) { toast.error('Fill all'); return; } exec('Creating election', () => getPartyContract(userParty!.address).createElection(BigInt(elStartTime), BigInt(elEndTime), BigInt(elCandDeadline)), 'cpel'); };
  const handleDeclareWinner = () => exec('Declaring winner', () => getPartyContract(userParty!.address).declareWinner(partyData.electionId), 'dw');
  const handleRegisterWithEB = () => exec('Registering with EB', () => getPartyContract(userParty!.address).registerWinnerWithElectionBody(partyData.electionId), 'rweb');
  const handleSetMembershipFee = () => { if (!newMemberFee) { toast.error('Enter amount'); return; } exec('Setting membership fee', () => getPartyContract(userParty!.address).setMembershipFee(ethers.parseEther(newMemberFee)), 'smf'); };
  const handleSetCandidacyFee = () => { if (!newCandFee) { toast.error('Enter amount'); return; } exec('Setting candidacy fee', () => getPartyContract(userParty!.address).setCandidacyFee(ethers.parseEther(newCandFee)), 'scf'); };
  const handleRemoveMember = () => { if (!rmMemberAddr || !rmMemberNin) { toast.error('Fill fields'); return; } exec('Removing member', () => getPartyContract(userParty!.address).removeMember(rmMemberAddr, BigInt(rmMemberNin)), 'rmmem'); };
  const handleRemoveCandidate = () => { if (!rmCandElId || !rmCandId || !rmCandAddr) { toast.error('Fill fields'); return; } exec('Removing candidate', () => getPartyContract(userParty!.address).removeCandidate(BigInt(rmCandElId), BigInt(rmCandId), rmCandAddr), 'rmcand'); };

  if (!isConnected) return <div className="max-w-lg mx-auto px-4 py-20 text-center"><div className="glass-card p-10"><h2 className="text-2xl font-bold text-gray-900 mb-4">Connect Wallet</h2><button onClick={openModal} className="btn-primary">Connect Wallet</button></div></div>;
  if (!userParty) return <div className="max-w-lg mx-auto px-4 py-20 text-center"><div className="glass-card p-10"><h2 className="text-2xl font-bold text-gray-900 mb-4">No Party</h2><p className="text-gray-500 mb-6">Join a party first.</p><Link to="/parties" className="btn-primary">Browse Parties</Link></div></div>;
  if (loading) return <div className="max-w-5xl mx-auto px-4 py-12"><div className="skeleton h-8 w-64 mb-4" /><div className="skeleton h-48" /></div>;

  const now = Math.floor(Date.now() / 1000);
  const canRegCandidate = electionDetails && now < electionDetails.candidateRegDeadline;
  const isVotingPeriod = electionDetails && now >= electionDetails.startTime && now <= electionDetails.endTime;
  const primaryEnded = electionDetails && now > electionDetails.endTime;
  const totalPrimaryVotes = candidates.reduce((a, c) => a + c.voteCount, 0);

  return (
    <div className="max-w-5xl mx-auto px-4 py-8">
      <div className="flex flex-wrap items-center gap-4 mb-8 animate-fade-up">
        <div className="w-14 h-14 rounded-2xl brand-gradient flex items-center justify-center text-white text-2xl font-bold shadow-lg">{partyData?.name?.charAt(0) || 'P'}</div>
        <div><h1 className="text-3xl font-bold text-gray-900">{partyData?.name}</h1><div className="flex gap-2 mt-1">{userParty.isLeader && <span className="badge badge-brand">Leader</span>}{userParty.isAdmin && <span className="badge badge-brand">Admin</span>}{userParty.isMember && <span className="badge badge-info">Member</span>}</div></div>
        {countdown && <div className="ml-auto"><p className="text-sm font-mono text-brand-600 font-semibold">{countdown}</p></div>}
      </div>

      <div className="grid sm:grid-cols-3 gap-4 mb-8 animate-fade-up stagger-1">
        <div className="glass-card p-5"><p className="text-xs text-gray-400 font-semibold uppercase mb-1">Election ID</p><p className="text-2xl font-bold text-gray-900">{partyData?.electionId || '\u2014'}</p></div>
        <div className="glass-card p-5"><p className="text-xs text-gray-400 font-semibold uppercase mb-1">Membership Fee</p><p className="text-2xl font-bold text-gray-900">{parseFloat(partyData?.membershipFee || 0).toLocaleString()} <span className="text-sm font-normal text-gray-400">NAT</span></p></div>
        <div className="glass-card p-5"><p className="text-xs text-gray-400 font-semibold uppercase mb-1">Candidacy Fee</p><p className="text-2xl font-bold text-gray-900">{parseFloat(partyData?.candidacyFee || 0).toLocaleString()} <span className="text-sm font-normal text-gray-400">NAT</span></p></div>
      </div>

      {memberInfo && <div className="glass-card p-5 mb-6 animate-fade-up stagger-2"><h3 className="text-sm font-semibold text-gray-400 uppercase tracking-wide mb-3">Your Membership</h3><div className="grid sm:grid-cols-3 gap-4 text-sm"><div><span className="text-gray-400">ID</span><p className="font-bold text-gray-900">#{memberInfo.id}</p></div><div><span className="text-gray-400">Name</span><p className="font-bold text-gray-900">{memberInfo.name}</p></div><div><span className="text-gray-400">Status</span><p className="font-bold text-emerald-600">Active</p></div></div></div>}

      {(userParty.isLeader || userParty.isAdmin) && (
        <div className="glass-card p-6 mb-6 border-l-4 border-brand-500 animate-fade-up stagger-2">
          <h3 className="text-lg font-bold text-gray-900 mb-4">{userParty.isLeader ? 'Leader' : 'Admin'} Actions</h3>
          <div className="flex flex-wrap gap-3 mb-4">
            {userParty.isLeader && <button onClick={handleSetElectionId} disabled={submitting} className="btn-secondary text-sm">Sync Election ID</button>}
            {userParty.isLeader && <button onClick={() => setShowCreateElection(!showCreateElection)} className="btn-secondary text-sm">{showCreateElection ? 'Cancel' : 'Create Primary Election'}</button>}
            {userParty.isLeader && <button onClick={() => setShowSetMemberFee(!showSetMemberFee)} className="btn-secondary text-sm">{showSetMemberFee ? 'Cancel' : 'Set Membership Fee'}</button>}
            {userParty.isAdmin && <button onClick={() => setShowSetCandFee(!showSetCandFee)} className="btn-secondary text-sm">{showSetCandFee ? 'Cancel' : 'Set Candidacy Fee'}</button>}
            {userParty.isLeader && <button onClick={() => setShowRemoveMember(!showRemoveMember)} className="btn-secondary text-sm">{showRemoveMember ? 'Cancel' : 'Remove Member'}</button>}
            {userParty.isLeader && <button onClick={() => setShowRemoveCandidate(!showRemoveCandidate)} className="btn-secondary text-sm">{showRemoveCandidate ? 'Cancel' : 'Remove Candidate'}</button>}
            {primaryEnded && userParty.isLeader && <><button onClick={handleDeclareWinner} disabled={submitting} className="btn-primary text-sm">Declare Winner</button><button onClick={handleRegisterWithEB} disabled={submitting} className="btn-primary text-sm">Register w/ EB</button></>}
          </div>
          {showCreateElection && <div className="p-5 rounded-xl bg-surface-100 space-y-3 mb-4 animate-slide-down"><h4 className="font-semibold text-gray-900 text-sm">Create Primary Election</h4><p className="text-xs text-gray-500">Times in seconds from now.</p><div className="grid sm:grid-cols-3 gap-3"><div><label className="text-xs font-semibold text-gray-600">Cand Deadline (s)</label><input type="number" value={elCandDeadline} onChange={e => setElCandDeadline(e.target.value)} className="input-field text-sm mt-1" /></div><div><label className="text-xs font-semibold text-gray-600">Start (s)</label><input type="number" value={elStartTime} onChange={e => setElStartTime(e.target.value)} className="input-field text-sm mt-1" /></div><div><label className="text-xs font-semibold text-gray-600">End (s)</label><input type="number" value={elEndTime} onChange={e => setElEndTime(e.target.value)} className="input-field text-sm mt-1" /></div></div><button onClick={handleCreatePrimaryElection} disabled={submitting} className="btn-primary text-sm">{submitting ? 'Creating...' : 'Create'}</button></div>}
          {showSetMemberFee && <div className="p-5 rounded-xl bg-surface-100 space-y-3 mb-4 animate-slide-down"><h4 className="font-semibold text-gray-900 text-sm">Set Membership Fee</h4><div className="flex gap-3 max-w-md"><input type="text" value={newMemberFee} onChange={e => setNewMemberFee(e.target.value)} className="input-field text-sm font-mono flex-1" placeholder="NAT amount" /><button onClick={handleSetMembershipFee} disabled={submitting} className="btn-primary text-sm">Set</button></div></div>}
          {showSetCandFee && <div className="p-5 rounded-xl bg-surface-100 space-y-3 mb-4 animate-slide-down"><h4 className="font-semibold text-gray-900 text-sm">Set Candidacy Fee</h4><div className="flex gap-3 max-w-md"><input type="text" value={newCandFee} onChange={e => setNewCandFee(e.target.value)} className="input-field text-sm font-mono flex-1" placeholder="NAT amount" /><button onClick={handleSetCandidacyFee} disabled={submitting} className="btn-primary text-sm">Set</button></div></div>}
          {showRemoveMember && <div className="p-5 rounded-xl bg-red-50/50 border border-red-100 space-y-3 mb-4 animate-slide-down"><h4 className="font-semibold text-red-800 text-sm">Remove Member</h4><p className="text-xs text-gray-500">Revokes membership, allows them to join another party.</p><input type="text" value={rmMemberAddr} onChange={e => setRmMemberAddr(e.target.value)} className="input-field text-sm font-mono" placeholder="Address (0x...)" /><input type="number" value={rmMemberNin} onChange={e => setRmMemberNin(e.target.value)} className="input-field text-sm font-mono" placeholder="NIN" /><button onClick={handleRemoveMember} disabled={submitting} className="btn-primary text-sm !bg-red-600 hover:!bg-red-700">Remove</button></div>}
          {showRemoveCandidate && <div className="p-5 rounded-xl bg-red-50/50 border border-red-100 space-y-3 mb-4 animate-slide-down"><h4 className="font-semibold text-red-800 text-sm">Remove Candidate</h4><p className="text-xs text-gray-500">Only before election starts.</p><div className="grid sm:grid-cols-3 gap-3"><input type="number" value={rmCandElId} onChange={e => setRmCandElId(e.target.value)} className="input-field text-sm font-mono" placeholder="Election ID" /><input type="number" value={rmCandId} onChange={e => setRmCandId(e.target.value)} className="input-field text-sm font-mono" placeholder="Candidate ID" /><input type="text" value={rmCandAddr} onChange={e => setRmCandAddr(e.target.value)} className="input-field text-sm font-mono" placeholder="Address (0x...)" /></div><button onClick={handleRemoveCandidate} disabled={submitting} className="btn-primary text-sm !bg-red-600 hover:!bg-red-700">Remove</button></div>}
        </div>
      )}

      {roles.isPartyMember && canRegCandidate && (
        <div className="glass-card p-6 mb-6 animate-fade-up stagger-3"><h3 className="text-lg font-bold text-gray-900 mb-3">Run as Candidate</h3><p className="text-sm text-gray-500 mb-4">Deadline: {new Date(electionDetails.candidateRegDeadline * 1000).toLocaleString()}</p>
          <div className="flex flex-wrap gap-3"><button onClick={handlePayCandidacy} disabled={submitting} className="btn-secondary text-sm">1. Pay Fee ({parseFloat(partyData?.candidacyFee || 0).toLocaleString()} NAT)</button><button onClick={() => setShowCandForm(true)} className="btn-primary text-sm">2. Register</button></div>
          {showCandForm && <div className="mt-4 p-4 rounded-xl bg-surface-100 space-y-3 animate-slide-down"><input type="text" value={candName} onChange={e => setCandName(e.target.value)} className="input-field text-sm" placeholder="Name" /><input type="number" value={candNin} onChange={e => setCandNin(e.target.value)} className="input-field text-sm font-mono" placeholder="NIN" /><div className="flex gap-3"><button onClick={() => setShowCandForm(false)} className="btn-ghost text-sm">Cancel</button><button onClick={handleRegisterCandidate} disabled={submitting} className="btn-primary text-sm">{submitting ? 'Registering...' : 'Register'}</button></div></div>}
        </div>
      )}

      <div className="animate-fade-up stagger-3">
        <h3 className="text-lg font-bold text-gray-900 mb-4">{isVotingPeriod && !hasVotedPrimary ? 'Vote' : 'Candidates'}{candidates.length > 0 && <span className="text-gray-400 font-normal ml-2 text-sm">({candidates.length})</span>}</h3>
        {candidates.length === 0 ? <div className="glass-card p-8 text-center"><p className="text-gray-400">No candidates yet.</p></div> : (
          <div className="space-y-3">{candidates.map(cand => { const pct = totalPrimaryVotes > 0 ? ((cand.voteCount / totalPrimaryVotes) * 100).toFixed(1) : '0'; return (
            <div key={cand.id} className="glass-card p-5 flex items-center gap-4">
              <div className="w-11 h-11 rounded-xl bg-brand-50 flex items-center justify-center text-brand-600 font-bold">#{cand.id}</div>
              <div className="flex-1 min-w-0"><p className="font-bold text-gray-900">{cand.name}</p><p className="text-xs text-gray-400 font-mono truncate">{cand.walletAddress}</p>{(primaryEnded || totalPrimaryVotes > 0) && <div className="mt-2"><div className="h-1.5 bg-gray-100 rounded-full overflow-hidden w-48"><div className="h-full brand-gradient rounded-full" style={{ width: `${pct}%` }} /></div><p className="text-xs text-gray-400 mt-0.5">{cand.voteCount} votes ({pct}%)</p></div>}</div>
              {isVotingPeriod && !hasVotedPrimary && <button onClick={() => handleVotePrimary(cand.id)} disabled={submitting} className="btn-primary text-sm !py-2">Vote</button>}
            </div>); })}</div>
        )}
        {hasVotedPrimary && <p className="mt-4 text-sm text-emerald-600 font-semibold">\u2713 You voted in this primary.</p>}
      </div>
    </div>
  );
}