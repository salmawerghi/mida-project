import type { ReactElement } from 'react'
import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router'

import { pageDuCompte, type Compte, type ServiceRestaurant } from './auth/service'
import { FournisseurSession, useSession } from './auth/session'
import type { LecteurAlerte } from './commandes/son'
import { FournisseurCommandes } from './commandes/suivi'
import { Chargement } from './composants'
import Attente from './pages/Attente'
import Commandes from './pages/Commandes'
import Connexion from './pages/Connexion'
import Inscription from './pages/Inscription'
import Menu from './pages/Menu'
import PlatForm from './pages/PlatForm'
import Profil from './pages/Profil'
import Tableau from './pages/Tableau'

/**
 * Page réservée aux responsables connectés. Sans session : retour à la
 * connexion. Connecté mais pas sur la bonne page pour l'état de son
 * restaurant (pas encore inscrit, en attente, validé) : redirection.
 */
export function PageProtegee({
  page,
  rendu,
}: {
  page: '/attente' | '/tableau' | '/profil' | '/menu' | '/commandes'
  rendu: (compte: Compte) => ReactElement
}) {
  const { etat } = useSession()
  const location = useLocation()
  if (etat.statut === 'chargement') return <Chargement />
  if (etat.statut === 'deconnecte') return <Navigate to="/connexion" replace state={{ depuis: location.pathname }} />
  const attendue = pageDuCompte(etat.compte)
  // Profil et menu sont ouverts dès que le restaurant est inscrit, même avant sa validation (US07, US09).
  // Les commandes, seulement pour un restaurant validé (comme le tableau de bord).
  const autorisee =
    page === '/profil' || page === '/menu'
      ? etat.compte.restaurant !== null
      : page === '/commandes'
        ? attendue === '/tableau'
        : attendue === page
  if (!autorisee) return <Navigate to={attendue} replace />
  return rendu(etat.compte)
}

function Accueil() {
  const { etat } = useSession()
  if (etat.statut === 'chargement') return <Chargement />
  return <Navigate to={etat.statut === 'connecte' ? pageDuCompte(etat.compte) : '/connexion'} replace />
}

/** `lecteur` : alerte sonore des nouvelles commandes (remplaçable dans les tests). */
export function Routage({ lecteur }: { lecteur?: LecteurAlerte } = {}) {
  return (
    <FournisseurCommandes lecteur={lecteur}>
      <Routes>
        <Route path="/" element={<Accueil />} />
        <Route path="/connexion" element={<Connexion />} />
        <Route path="/inscription" element={<Inscription />} />
        <Route path="/attente" element={<PageProtegee page="/attente" rendu={(c) => <Attente compte={c} />} />} />
        <Route path="/tableau" element={<PageProtegee page="/tableau" rendu={(c) => <Tableau compte={c} />} />} />
        <Route path="/menu" element={<PageProtegee page="/menu" rendu={(c) => <Menu compte={c} />} />} />
        <Route path="/menu/plats/nouveau" element={<PageProtegee page="/menu" rendu={(c) => <PlatForm compte={c} />} />} />
        <Route path="/menu/plats/:id" element={<PageProtegee page="/menu" rendu={(c) => <PlatForm compte={c} />} />} />
        <Route path="/profil" element={<PageProtegee page="/profil" rendu={(c) => <Profil compte={c} />} />} />
        <Route path="/commandes" element={<PageProtegee page="/commandes" rendu={(c) => <Commandes compte={c} />} />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </FournisseurCommandes>
  )
}

export default function App({ service }: { service: ServiceRestaurant }) {
  return (
    <FournisseurSession service={service}>
      <BrowserRouter>
        <Routage />
      </BrowserRouter>
    </FournisseurSession>
  )
}
