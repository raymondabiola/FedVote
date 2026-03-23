import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useWeb3 } from '../context/Web3Context';
import { ethers } from 'ethers';
import toast from 'react-hot-toast';

export default function VoterDashboard() {
  const { account, contracts, roles, voterData, userParty, refreshRoles, openModal, isConnected } = useWeb3();
  const [tokenBalance, setTokenBalance] = useState('0');
  const [incentivesEligible, setIncentivesEligible] = useState(false);
  const [totalIncentives, setTotalIncentives] = useState('0');
  const [claiming, setClaiming] = useState(false);
  const [electionInfo, setElectionInfo] = useState<any>(null);
  const [isAccredited, setIsAccredited] = useState(false);
  const [hasVoted, setHasVoted] = useState(false);

  useEffect(() => {
    if (!account || !contracts.nationalToken) return;
    const fetchData = async () => {
      try {
        const [bal, totalInc] = await Promise.all([
          contracts.nationalToken!.balanceOf(account),
          contracts.voterIncentives!.totalIncentivesReceived(account),
        ]);
        setTokenBalance(ethers.formatEther(bal));
        setTotalIncentives(ethers.formatEther(totalInc));
        try { setIncentivesEligible(await contracts.voterIncentives!.checkEligibility(account)); } catch { setIncentivesEligible(false); }

        const elId = await contracts.election!.currentElectionId();
        if (Number(elId) > 0) {
          const elData = await contracts.election!.elections(elId);
          setElectionInfo({ id: Number(elId), name: elData[0], startTime: Number(elData[2]), endTime: Number(elData[3]), isActive: elData[4] });
          setIsAccredited(await contracts.election!.isAccreditedForElection(elId, account));
          setHasVoted(await contracts.election!.hasVoted(elId, account));
        }
      } catch (e) { console.log('Dashboard data error:', e); }
    };
    fetchData();
  }, [account, contracts]);

  const handleClaimIncentives = async () => {
    setClaiming(true);
    try {
      const tx = await contracts.voterIncentives!.claimIncentives();
      toast.loading('Claiming rewards...', { id: 'claim' });
      await tx.wait();
      toast.success('Rewards claimed successfully!', { id: 'claim' });
      await refreshRoles();
    } catch (err: any) { toast.error(err?.reason || 'Failed to claim incentives', { id: 'claim' }); }
    finally { setClaiming(false); }
  };

  if (!isConnected) return (<div className="max-w-lg mx-auto px-4 py-20 text-center"><div className="glass-card p-10"><h2 className="text-2xl font-bold text-gray-900 mb-4">Connect Wallet</h2><p className="text-gray-500 mb-6">Connect your wallet to view your voter dashboard.</p><button onClick={openModal} className="btn-primary">Connect Wallet</button></div></div>);
  if (!roles.isRegisteredVoter) return (<div className="max-w-lg mx-auto px-4 py-20 text-center"><div className="glass-card p-10"><h2 className="text-2xl font-bold text-gray-900 mb-4">Not Registered</h2><p className="text-gray-500 mb-6">You need to register as a voter first.</p><Link to="/register" className="btn-primary">Register Now</Link></div></div>);

  const now = Math.floor(Date.now() / 1000);
  const electionActive = electionInfo && electionInfo.isActive && now >= electionInfo.startTime && now <= electionInfo.endTime;
  const electionUpcoming = electionInfo && electionInfo.isActive && now < electionInfo.startTime;

  return (
    <div className="max-w-6xl mx-auto px-4 py-8">
      <div className="mb-8 animate-fade-up">
        <h1 className="text-3xl font-bold text-gray-900">Welcome back, <span className="text-gradient">{voterData?.name || 'Voter'}</span></h1>
        <p className="text-gray-500 mt-1">Your civic participation dashboard</p>
      </div>

      <div className="grid sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div className="glass-card p-5 animate-fade-up stagger-1">
          <div className="flex items-center justify-between mb-3"><span className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Vote Streak</span><div className="w-9 h-9 rounded-xl bg-brand-50 flex items-center justify-center"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#6C63FF" strokeWidth="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" /></svg></div></div>
          <p className="text-3xl font-bold text-gray-900">{voterData?.streak || 0}</p>
          <p className="text-xs text-gray-400 mt-1">consecutive elections</p>
          {voterData && voterData.streak > 0 && voterData.streak < 3 && (
            <div className="mt-3"><div className="h-1.5 bg-gray-100 rounded-full overflow-hidden"><div className="h-full brand-gradient rounded-full transition-all" style={{ width: `${(voterData.streak / 3) * 100}%` }} /></div><p className="text-[10px] text-brand-500 mt-1">{3 - voterData.streak} more to earn badge</p></div>
          )}
        </div>
        <div className="glass-card p-5 animate-fade-up stagger-2">
          <div className="flex items-center justify-between mb-3"><span className="text-xs font-semibold text-gray-400 uppercase tracking-wide">NAT Balance</span><div className="w-9 h-9 rounded-xl bg-emerald-50 flex items-center justify-center"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#10b981" strokeWidth="2"><circle cx="12" cy="12" r="10" /><path d="M16 8h-6a2 2 0 100 4h4a2 2 0 010 4H8" /><path d="M12 18V6" /></svg></div></div>
          <p className="text-3xl font-bold text-gray-900">{parseFloat(tokenBalance).toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
          <p className="text-xs text-gray-400 mt-1">NAT tokens</p>
        </div>
        <div className="glass-card p-5 animate-fade-up stagger-3">
          <div className="flex items-center justify-between mb-3"><span className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Democracy Badge</span><div className={`w-9 h-9 rounded-xl flex items-center justify-center ${roles.hasDemocracyBadge ? 'bg-amber-50' : 'bg-gray-50'}`}><span className="text-lg">{roles.hasDemocracyBadge ? '🏅' : '🔒'}</span></div></div>
          <p className="text-xl font-bold text-gray-900">{roles.hasDemocracyBadge ? 'Earned' : 'Not Yet'}</p>
          <p className="text-xs text-gray-400 mt-1">{roles.hasDemocracyBadge ? 'Soulbound NFT holder' : 'Reach streak of 3'}</p>
        </div>
        <div className="glass-card p-5 animate-fade-up stagger-4">
          <div className="flex items-center justify-between mb-3"><span className="text-xs font-semibold text-gray-400 uppercase tracking-wide">Total Rewards</span><div className="w-9 h-9 rounded-xl bg-purple-50 flex items-center justify-center"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#8b5cf6" strokeWidth="2"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" /></svg></div></div>
          <p className="text-3xl font-bold text-gray-900">{parseFloat(totalIncentives).toLocaleString(undefined, { maximumFractionDigits: 0 })}</p>
          <p className="text-xs text-gray-400 mt-1">NAT earned</p>
          {incentivesEligible && <button onClick={handleClaimIncentives} disabled={claiming} className="btn-primary text-xs !py-2 !px-4 mt-3 w-full">{claiming ? 'Claiming...' : 'Claim Rewards'}</button>}
        </div>
      </div>

      <div className="grid md:grid-cols-2 gap-6 mb-8">
        <div className="glass-card p-6 animate-fade-up">
          <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#6C63FF" strokeWidth="2"><path d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z" /></svg>National Election</h3>
          {electionInfo ? (
            <div>
              <div className="flex items-center gap-2 mb-3"><span className="font-semibold text-gray-900">{electionInfo.name || `Election #${electionInfo.id}`}</span>
                {electionActive && <span className="badge badge-success">Active</span>}{electionUpcoming && <span className="badge badge-warning">Upcoming</span>}{!electionInfo.isActive && <span className="badge badge-error">Ended</span>}
              </div>
              <div className="space-y-2 text-sm text-gray-500"><p>Start: {new Date(electionInfo.startTime * 1000).toLocaleString()}</p><p>End: {new Date(electionInfo.endTime * 1000).toLocaleString()}</p></div>
              <div className="flex gap-3 mt-4">
                {isAccredited ? <span className="badge badge-success">✓ Accredited</span> : electionInfo.isActive ? <Link to="/elections" className="btn-secondary text-sm !py-2">Accredit Yourself</Link> : null}
                {hasVoted ? <span className="badge badge-success">✓ Voted</span> : electionActive && isAccredited ? <Link to="/elections" className="btn-primary text-sm !py-2">Cast Your Vote →</Link> : null}
              </div>
            </div>
          ) : <p className="text-gray-400 text-sm">No active election at the moment.</p>}
        </div>
        <div className="glass-card p-6 animate-fade-up">
          <h3 className="text-lg font-bold text-gray-900 mb-4 flex items-center gap-2"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#6C63FF" strokeWidth="2"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 00-3-3.87" /><path d="M16 3.13a4 4 0 010 7.75" /></svg>Party Membership</h3>
          {userParty ? (
            <div>
              <div className="flex items-center gap-3 mb-3"><div className="w-10 h-10 rounded-xl brand-gradient flex items-center justify-center text-white font-bold">{userParty.name.charAt(0)}</div><div><p className="font-semibold text-gray-900">{userParty.name}</p><div className="flex gap-2">{userParty.isLeader && <span className="badge badge-brand text-[10px]">Leader</span>}{userParty.isMember && <span className="badge badge-info text-[10px]">Member</span>}</div></div></div>
              <Link to="/party" className="btn-secondary text-sm !py-2 mt-2 inline-flex">Go to Party Portal →</Link>
            </div>
          ) : (<div><p className="text-gray-400 text-sm mb-4">You haven't joined a party yet. Join one to participate in primaries.</p><Link to="/parties" className="btn-secondary text-sm !py-2">Browse Parties →</Link></div>)}
        </div>
      </div>

      <div className="glass-card p-6 animate-fade-up">
        <h3 className="text-sm font-semibold text-gray-400 uppercase tracking-wide mb-4">Your On-Chain Identity</h3>
        <div className="grid sm:grid-cols-2 gap-4 text-sm">
          <div><span className="text-gray-400">Wallet Address</span><p className="font-mono text-gray-900 mt-0.5 break-all">{account}</p></div>
          <div><span className="text-gray-400">Registration Status</span><p className="font-semibold text-emerald-600 mt-0.5">✓ Verified Voter</p></div>
        </div>
      </div>
    </div>
  );
}