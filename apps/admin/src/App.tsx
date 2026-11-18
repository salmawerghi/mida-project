import type { ReactElement } from 'react'
import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router'

import Cadre from './Cadre'
import { Chargement } from './composants'
import Clients from './pages/Clients'
import Commandes from './pages/Commandes'
import Connexion from './pages/Connexion'
import Demande from './pages/Demande'
import Livreurs from './pages/Livreurs'
import Parametres from './pages/Parametres'
import Restaurants from './pages/Restaurants'
import Tableau from './pages/Tableau'
import type { ServiceAdmin } from './service'
import { FournisseurSession, useSession } from './session'

/** Page réservée à l'administrateur connecté (US32) ; sinon retour à la connexion. */
function PageAdmin({ titre, page }: { titre: string; page: ReactElement }) {
  const { etat } = useSession()
  const location = useLocation()
  if (etat.statut === 'chargement') return <Chargement />
  if (etat.statut === 'deconnecte') return <Navigate to="/connexion" replace state={{ depuis: location.pathname }} />
  return (
    <Cadre compte={etat.compte} titre={titre}>
      {page}
    </Cadre>
  )
}

export function Routage() {
  return (
    <Routes>
      <Route path="/" element={<Navigate to="/tableau" replace />} />
      <Route path="/connexion" element={<Connexion />} />
      <Route path="/tableau" element={<PageAdmin titre="Vue d'ensemble" page={<Tableau />} />} />
      <Route path="/restaurants" element={<PageAdmin titre="Restaurants" page={<Restaurants />} />} />
      <Route path="/restaurants/:id" element={<PageAdmin titre="Demande d'inscription" page={<Demande />} />} />
      <Route path="/livreurs" element={<PageAdmin titre="Livreurs" page={<Livreurs />} />} />
      <Route path="/clients" element={<PageAdmin titre="Clients" page={<Clients />} />} />
      <Route path="/commandes" element={<PageAdmin titre="Commandes" page={<Commandes />} />} />
      <Route path="/parametres" element={<PageAdmin titre="Paramètres" page={<Parametres />} />} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App({ service }: { service: ServiceAdmin }) {
  return (
    <FournisseurSession service={service}>
      <BrowserRouter>
        <Routage />
      </BrowserRouter>
    </FournisseurSession>
  )
}
