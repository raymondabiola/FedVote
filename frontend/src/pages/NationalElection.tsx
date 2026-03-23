import React, { useState, useEffect, useCallback } from 'react';
import { useWeb3 } from '../context/Web3Context';
import { ethers } from 'ethers';
import { ADDRESSES, CHAIN_CONFIG, ElectionABI } from '../config/contracts';
import toast from 'react-hot-toast';

export default function NationalElection() {
  const { account, contracts, roles, refreshRoles, openModal, isConnected } = useWeb3();
  const [election, setElection] = useState<any>(null);
  const [parties, setParties] = useState<string[]>([]);
  const [isAccredited, setIsAccredited] = useState(false);
  const [hasVoted, setHasVoted] = useState(false);
  const [voteCounts, setVoteCounts] = useState<Record<string, number>>({});
  const [selectedParty, setSelectedParty] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [loading, setLoading] = useState(true);
  const [countdown, setCountdown] = useState('');
  const [result, setResult] = useState<any>(null);

  const fetchElectionData = useCallback(async () => {
    setLoading(true);
    try {
      const rpc = new ethers.JsonRpcProvider(CHAIN_CONFIG.rpcUrl);
      const elContract = new ethers.Contract(ADDRESSES.Election, ElectionABI, rpc);
      const elId = await elContract.currentElectionId();
      if (Number(elId) === 0) { setLoading(false); return; }
      const elData = await elContract.elections(elId);
      const elInfo = { id: Number(elId), name: elData[0], electionId: Number(elData[1]), startTime: Number(elData[2]), endTime: Number(elData[3]), isActive: elData[4], winner: elData[5], isTie: elData[6] };
      setElection(elInfo);
      const partyList: string[] = []; const counts: Record<string, number> = {};
      for (let i = 0; i < 20; i++) { try { const a = await elContract.electionParties(elId, i); if (a) { partyList.push(a); try { counts[a] = Number(await elContract.voteCounts(elId, a)); } catch { counts[a] = 0; } } } catch { break; } }
      setParties(partyList); setVoteCounts(counts);
      if (!elInfo.isActive) { try { const res = await elContract.getElectionResult(elId); setResult({ winner: res[0], isTie: res[1] }); } catch {} }
      if (account && contracts.election) { const [accr, voted] = await Promise.all([contracts.election.isAccreditedForElection(elId, account), contracts.election.hasVoted(elId, account)]); setIsAccredited(accr); setHasVoted(voted); }
    } catch (e) { console.log('Election fetch error:', e); }
    setLoading(false);
  }, [account, contracts]);

  useEffect(() => { fetchElectionData(); }, [fetchElectionData]);

  useEffect(() => {
    if (!election) return;
    const interval = setInterval(() => {
      const now = Math.floor(Date.now() / 1000); let target: number, label: string;
      if (now < election.startTime) { target = election.startTime; label = 'Starts in'; }
      else if (now < election.endTime) { target = election.endTime; label = 'Ends in'; }
      else { setCountdown('Election has ended'); clearInterval(interval); return; }
      const diff = target - now;
      setCountdown(`${label} ${Math.floor(diff / 3600)}h ${Math.floor((diff % 3600) / 60)}m ${diff % 60}s`);
    }, 1000);
    return () => clearInterval(interval);
  }, [election]);

  const handleAccredit = async () => { setSubmitting(true); try { const tx = await contracts.election!.accreditMyself(); toast.loading('Accrediting...', { id: 'accredit' }); await tx.wait(); toast.success('Successfully accredited!', { id: 'accredit' }); setIsAccredited(true); } catch (err: any) { toast.error(err?.reason || 'Accreditation failed', { id: 'accredit' }); } finally { setSubmitting(false); } };
  const handleVote = async () => { if (!selectedParty) { toast.error('Select a party'); return; } setSubmitting(true); try { const tx = await contracts.election!.vote(selectedParty); toast.loading('Casting vote...', { id: 'vote' }); await tx.wait(); toast.success('Vote cast!', { id: 'vote' }); setHasVoted(true); await refreshRoles(); fetchElectionData(); } catch (err: any) { toast.error(err?.reason || 'Vote failed', { id: 'vote' }); } finally { setSubmitting(false); } };

  const now = Math.floor(Date.now() / 1000);
  const isVotingPeriod = election && election.isActive && now >= election.startTime && now <= election.endTime;
  const isUpcoming = election && election.isActive && now < election.startTime;
  const isEnded = election && (!election.isActive || now > election.endTime);
  const totalVotes = Object.values(voteCounts).reduce((a, b) => a + b, 0);

  if (loading) return <div className="max-w-4xl mx-auto px-4 py-12"><div className="skeleton h-8 w-64 mb-4" /><div className="skeleton h-64 w-full mt-6" /></div>;

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <div className="mb-8 animate-fade-up"><span className="badge badge-brand mb-3">National Election</span><h1 className="text-3xl font-bold text-gray-900">Federal General Election</h1></div>
      {!election ? <div className="glass-card p-12 text-center"><p className="text-lg font-semibold text-gray-400">No active election</p></div> : (<>
        <div className="glass-card p-6 mb-6 animate-fade-up stagger-1">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div><h2 className="text-xl font-bold text-gray-900">{election.name || `Election #${election.id}`}</h2><div className="flex items-center gap-3 mt-2 text-sm text-gray-500"><span>Start: {new Date(election.startTime * 1000).toLocaleString()}</span><span>·</span><span>End: {new Date(election.endTime * 1000).toLocaleString()}</span></div></div>
            <div className="text-right">{isVotingPeriod && <span className="badge badge-success mb-1">🟢 Voting Live</span>}{isUpcoming && <span className="badge badge-warning mb-1">⏳ Upcoming</span>}{isEnded && <span className="badge badge-error mb-1">Ended</span>}<p className="text-sm font-mono text-brand-600 font-semibold">{countdown}</p></div>
          </div>
        </div>
        {isEnded && result && <div className={`glass-card p-6 mb-6 animate-fade-up ${result.isTie ? 'border-l-4 border-amber-400' : 'border-l-4 border-emerald-400'}`}><h3 className="text-lg font-bold text-gray-900 mb-1">{result.isTie ? '⚖️ Tie' : `🏆 Winner: ${result.winner}`}</h3><p className="text-sm text-gray-500">{result.isTie ? 'No clear winner.' : `${result.winner} won with ${voteCounts[result.winner] || 0} out of ${totalVotes} votes.`}</p></div>}
        {isConnected && roles.isRegisteredVoter && election.isActive && <div className="glass-card p-6 mb-6 animate-fade-up stagger-2"><h3 className="text-lg font-bold text-gray-900 mb-4">Your Participation</h3><div className="flex flex-wrap gap-3">{!isAccredited ? <button onClick={handleAccredit} disabled={submitting} className="btn-primary">{submitting ? 'Processing...' : 'Accredit Yourself'}</button> : <span className="badge badge-success text-sm">✓ Accredited</span>}{hasVoted && <span className="badge badge-success text-sm">✓ Vote Cast</span>}</div></div>}
        <div className="animate-fade-up stagger-3">
          <h3 className="text-lg font-bold text-gray-900 mb-4">{isVotingPeriod && isAccredited && !hasVoted ? 'Cast Your Vote' : 'Participating Parties'}</h3>
          <div className="grid sm:grid-cols-2 gap-4">{parties.map(acronym => { const votes = voteCounts[acronym] || 0; const pct = totalVotes > 0 ? ((votes / totalVotes) * 100).toFixed(1) : '0'; const isSelected = selectedParty === acronym; return (
            <div key={acronym} onClick={() => { if (isVotingPeriod && isAccredited && !hasVoted) setSelectedParty(acronym); }} className={`glass-card p-5 transition-all cursor-pointer ${isSelected ? 'ring-2 ring-brand-500 bg-brand-50/30' : 'hover:shadow-md'} ${isVotingPeriod && isAccredited && !hasVoted ? '' : 'cursor-default'}`}>
              <div className="flex items-center justify-between mb-3"><div className="flex items-center gap-3"><div className="w-11 h-11 rounded-xl brand-gradient flex items-center justify-center text-white font-bold text-lg">{acronym.charAt(0)}</div><div><p className="font-bold text-gray-900">{acronym}</p><p className="text-xs text-gray-400">{votes} vote{votes !== 1 ? 's' : ''}</p></div></div>{isSelected && <div className="w-6 h-6 rounded-full bg-brand-500 flex items-center justify-center"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3"><polyline points="20 6 9 17 4 12" /></svg></div>}</div>
              {(isEnded || totalVotes > 0) && <div><div className="h-2 bg-gray-100 rounded-full overflow-hidden"><div className="h-full brand-gradient rounded-full transition-all duration-500" style={{ width: `${pct}%` }} /></div><p className="text-xs text-gray-400 mt-1">{pct}%</p></div>}
            </div>); })}</div>
          {isVotingPeriod && isAccredited && !hasVoted && <div className="mt-6"><button onClick={handleVote} disabled={!selectedParty || submitting} className="btn-primary text-base !py-3.5 !px-10">{submitting ? 'Submitting...' : `Vote for ${selectedParty || '...'}`}</button></div>}
        </div>
        {!isConnected && <div className="glass-card p-8 text-center mt-6"><p className="text-gray-500 mb-4">Connect your wallet to participate.</p><button onClick={openModal} className="btn-primary">Connect Wallet</button></div>}
      </>)}
    </div>
  );
}