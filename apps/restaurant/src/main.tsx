import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import App from './App'
import { creerClientSupabase, ServiceRestaurantSupabase } from './auth/serviceSupabase'
import './index.css'

const service = new ServiceRestaurantSupabase(creerClientSupabase())

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App service={service} />
  </StrictMode>,
)
