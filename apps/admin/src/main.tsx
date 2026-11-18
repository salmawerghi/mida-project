import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'

import App from './App'
import './admin.css'
import './index.css'
import { creerClientSupabase, ServiceAdminSupabase } from './serviceSupabase'

const service = new ServiceAdminSupabase(creerClientSupabase())

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App service={service} />
  </StrictMode>,
)
