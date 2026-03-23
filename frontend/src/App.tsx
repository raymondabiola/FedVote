import React from 'react';
import { Routes, Route } from 'react-router-dom';
import Navbar from './components/Navbar';
import Landing from './pages/Landing';
import VoterRegistration from './pages/VoterRegistration';
import VoterDashboard from './pages/VoterDashboard';
import NationalElection from './pages/NationalElection';
import PartiesList from './pages/PartiesList';
import PartyPortal from './pages/PartyPortal';
import AdminPanel from './pages/AdminPanel';


export default function App() {
  return (
    <div className="min-h-screen bg-surface-50">
    <Navbar />
      <Routes>
        <Route path="/" element={<Landing />} />
        <Route path="/register" element={<VoterRegistration />} />
        <Route path="/dashboard" element={<VoterDashboard />} />
        <Route path="/elections" element={<NationalElection />} />
        <Route path="/parties" element={<PartiesList />} />
        <Route path="/party" element={<PartyPortal />} />
        <Route path="/admin" element={<AdminPanel />} />
      </Routes>
    </div>
  );
}
