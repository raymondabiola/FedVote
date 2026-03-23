import React, { useState, useEffect } from 'react';
import { useWeb3 } from '../context/Web3Context';
import { ethers } from 'ethers';
import { CHAIN_CONFIG, ADDRESSES, PoliticalPartiesManagerFactoryABI, PoliticalPartyManagerABI } from '../config/contracts';
import toast from 'react-hot-toast';

export default function PartiesList() {
  const { account, contracts, roles, userParty, refreshRoles, getPartyContract, isConnected, openModal } = useWeb3();
  const [parties, setParties] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [joining, setJoining] = useState<string | null>(null);
  const [joinStep, setJoinStep] = useState('');
  const [joinNin, setJoinNin] = useState('');
  const [joinName, setJoinName] = useState('');
  const [showJoinModal, setShowJoinModal] = useState<any>(null);
  const [showRegisterParty, setShowRegisterParty] = useState(false);
  const [rpName, setRpName] = useState('');
  const [rpAcronym, setRpAcronym] = useState('');
  const [rpElectionId, setRpElectionId] = useState('');
  const [rpSubmitting, setRpSubmitting] = useState(false);

  useEffect(() => {
    const fetchParties = async () => {
      setLoading(true);
      try {
        const rpc = new ethers.JsonRpcProvider(CHAIN_CONFIG.rpcUrl);
        const factory = new ethers.Contract(ADDRESSES.PoliticalPartiesManagerFactory, PoliticalPartiesManagerFactoryABI, rpc);
        const addresses: string[] = await factory.getAllPoliticalParty();
        const list: any[] = [];
        for (const addr of addresses) {
          try {
            const pc = new ethers.Contract(addr, PoliticalPartyManagerABI, rpc);
            const [name, chairman, memberFee, candFee, membCount] = await Promise.all([pc.partyName(), pc.chairman(), pc.membershipFee().catch(() => 0n), pc.candidacyFee().catch(() => 0n), pc.memberId().catch(() => 0n)]);
            list.push({ address: addr, name, chairman, membershipFee: ethers.formatEther(memberFee), candidacyFee: ethers.formatEther(candFee), memberCount: Number(membCount) });
          } catch { list.push({ address: addr, name: 'Unknown', chairman: '', membershipFee: '0', candidacyFee: '0', memberCount: 0 }); }
        }
        setParties(list);
      } catch (e) { console.log('Parties fetch error:', e); }
      setLoading(false);
    };
    fetchParties();
  }, []);

  const handleJoinParty = async (party: any) => {
    if (!account) { toast.error('Connect wallet first'); return; }
    if (!joinNin || !joinName) { toast.error('Enter NIN and name'); return; }
    setJoining(party.address);
    try {
      const pc = getPartyContract(party.address); const fee = await pc.membershipFee();
      setJoinStep('approve'); toast.loading('Approving token spend...', { id: 'join' }); await (await contracts.nationalToken!.approve(party.address, fee)).wait();
      setJoinStep('pay'); toast.loading('Paying membership fee...', { id: 'join' }); await (await pc.payForMembership(BigInt(joinNin))).wait();
      setJoinStep('register'); toast.loading('Registering as member...', { id: 'join' }); await (await pc.memberRegistration(joinName, BigInt(joinNin))).wait();
      toast.success(`Joined ${party.name}!`, { id: 'join' }); setShowJoinModal(null); setJoinNin(''); setJoinName(''); await refreshRoles();
    } catch (err: any) { toast.error(err?.reason || 'Failed to join party', { id: 'join' }); }
    finally { setJoining(null); setJoinStep(''); }
  };

  const handleRegisterParty = async () => {
    if (!rpName || !rpAcronym || !rpElectionId) { toast.error('Fill all fields'); return; }
    if (!contracts.electionBody || !contracts.nationalToken) { toast.error('Connect wallet'); return; }
    setRpSubmitting(true);
    try {
      const regFee = await contracts.electionBody.registrationFee();
      toast.loading('Approving token spend...', { id: 'regparty' }); await (await contracts.nationalToken.approve(ADDRESSES.NationalElectionBody, regFee)).wait();
      toast.loading('Registering party...', { id: 'regparty' }); await (await contracts.electionBody.registerParty(rpName, BigInt(rpElectionId), rpAcronym)).wait();
      toast.success('Party registration submitted! Awaiting approval.', { id: 'regparty' }); setShowRegisterParty(false); setRpName(''); setRpAcronym(''); setRpElectionId('');
    } catch (err: any) { toast.error(err?.reason || 'Registration failed', { id: 'regparty' }); }
    finally { setRpSubmitting(false); }
  };

  if (loading) return <div className="max-w-4xl mx-auto px-4 py-12"><div className="skeleton h-8 w-48 mb-4" /><div className="grid sm:grid-cols-2 gap-4">{[1,2,3].map(i => <div key={i} className="skeleton h-48" />)}</div></div>;

  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <div className="mb-8 animate-fade-up"><span className="badge badge-brand mb-3">Political Parties</span><h1 className="text-3xl font-bold text-gray-900">Registered Parties</h1><p className="text-gray-500 mt-1">Browse parties, join one, or register a new party with the National Election Body.</p></div>

      {/* Register Party with Election Body */}
      <div className="glass-card p-6 mb-8 animate-fade-up stagger-1">
        <div className="flex items-center justify-between">
          <div><h3 className="text-lg font-bold text-gray-900">Register a Party for Election</h3><p className="text-sm text-gray-500 mt-1">Any party representative can apply. Registration fee in NAT required.</p></div>
          {isConnected ? <button onClick={() => setShowRegisterParty(!showRegisterParty)} className="btn-secondary text-sm">{showRegisterParty ? 'Cancel' : 'Apply Now'}</button> : <button onClick={openModal} className="btn-primary text-sm">Connect Wallet</button>}
        </div>
        {showRegisterParty && (
          <div className="mt-5 p-5 rounded-xl bg-surface-100 space-y-4 animate-slide-down">
            <div className="grid sm:grid-cols-3 gap-3">
              <div><label className="text-xs font-semibold text-gray-600 mb-1 block">Party Name</label><input type="text" value={rpName} onChange={e => setRpName(e.target.value)} className="input-field text-sm" placeholder="e.g., All Progressives Congress" /></div>
              <div><label className="text-xs font-semibold text-gray-600 mb-1 block">Party Acronym</label><input type="text" value={rpAcronym} onChange={e => setRpAcronym(e.target.value)} className="input-field text-sm" placeholder="e.g., APC" /></div>
              <div><label className="text-xs font-semibold text-gray-600 mb-1 block">Election ID</label><input type="number" value={rpElectionId} onChange={e => setRpElectionId(e.target.value)} className="input-field text-sm font-mono" placeholder="e.g., 2026" /></div>
            </div>
            <p className="text-xs text-gray-400">You will approve then pay the fee. Application goes to pending until approved.</p>
            <button onClick={handleRegisterParty} disabled={rpSubmitting} className="btn-primary text-sm">{rpSubmitting ? 'Processing...' : 'Submit Application & Pay Fee'}</button>
          </div>
        )}
      </div>

      {parties.length === 0 ? <div className="glass-card p-12 text-center"><p className="text-lg text-gray-400">No parties registered yet.</p></div> : (
        <div className="grid sm:grid-cols-2 lg:grid-cols-3 gap-5">
          {parties.map((party, i) => (
            <div key={party.address} className={`glass-card p-6 card-hover animate-fade-up stagger-${(i % 4) + 1}`}>
              <div className="flex items-center gap-3 mb-4"><div className="w-12 h-12 rounded-xl brand-gradient flex items-center justify-center text-white text-xl font-bold shadow-lg">{party.name.charAt(0)}</div><div><h3 className="font-bold text-gray-900">{party.name}</h3><p className="text-xs text-gray-400">{party.memberCount} member{party.memberCount !== 1 ? 's' : ''}</p></div></div>
              <div className="space-y-2 text-sm mb-4"><div className="flex justify-between"><span className="text-gray-400">Membership Fee</span><span className="font-semibold text-gray-700">{parseFloat(party.membershipFee).toLocaleString()} NAT</span></div><div className="flex justify-between"><span className="text-gray-400">Candidacy Fee</span><span className="font-semibold text-gray-700">{parseFloat(party.candidacyFee).toLocaleString()} NAT</span></div></div>
              <div className="text-xs text-gray-400 font-mono break-all mb-4">{party.address}</div>
              {userParty?.address === party.address ? <span className="badge badge-success w-full justify-center">✓ Your Party</span> : userParty ? <span className="badge badge-warning w-full justify-center text-[10px]">Already in a party</span> : isConnected && roles.isRegisteredVoter ? <button onClick={() => setShowJoinModal(party)} className="btn-primary w-full text-sm !py-2.5">Join Party</button> : null}
            </div>
          ))}
        </div>
      )}

      {showJoinModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="glass-card p-8 max-w-md w-full animate-fade-up">
            <h3 className="text-xl font-bold text-gray-900 mb-1">Join {showJoinModal.name}</h3>
            <p className="text-sm text-gray-500 mb-5">Fee: <strong>{parseFloat(showJoinModal.membershipFee).toLocaleString()} NAT</strong></p>
            <div className="space-y-4"><div><label className="block text-sm font-semibold text-gray-700 mb-1">NIN</label><input type="number" value={joinNin} onChange={e => setJoinNin(e.target.value)} className="input-field font-mono" placeholder="Your NIN" /></div><div><label className="block text-sm font-semibold text-gray-700 mb-1">First Name</label><input type="text" value={joinName} onChange={e => setJoinName(e.target.value)} className="input-field" placeholder="Government-registered name" /></div></div>
            {joinStep && <div className="mt-4 p-3 rounded-xl bg-brand-50 text-sm text-brand-600">{joinStep === 'approve' ? '⏳ Approving...' : joinStep === 'pay' ? '⏳ Paying fee...' : '⏳ Registering...'}</div>}
            <div className="flex gap-3 mt-6"><button onClick={() => { setShowJoinModal(null); setJoinNin(''); setJoinName(''); }} className="btn-secondary flex-1" disabled={!!joining}>Cancel</button><button onClick={() => handleJoinParty(showJoinModal)} disabled={!!joining} className="btn-primary flex-1">{joining ? 'Processing...' : 'Join Party'}</button></div>
          </div>
        </div>
      )}
    </div>
  );
}