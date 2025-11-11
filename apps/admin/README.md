# Admin Dashboard

Modern admin dashboard for TelePrompt Pro built with React, TypeScript, and Tailwind CSS.

## Features

### Dashboard Overview
- **System metrics**: Active users, total scripts, recordings, revenue
- **Real-time updates**: WebSocket connection for live data
- **Quick stats**: Today's signups, active subscriptions, server status
- **Charts**: User growth, revenue trends, usage statistics

### User Management
- View all users with pagination and search
- Filter by subscription tier (Free, Creator, Professional, Enterprise)
- User details: Profile, subscription, activity history
- Actions: Suspend, delete, reset password, upgrade/downgrade subscription

### Content Management
- Browse all scripts and recordings
- Moderation tools: Flag inappropriate content, delete
- Analytics: Most popular scripts, categories, templates

### Subscription Management
- View all subscriptions with status filters
- Revenue analytics by tier
- Churn analysis
- Manual subscription adjustments

### Analytics & Reporting
- User engagement metrics
- Revenue reports (MRR, ARR, churn rate)
- Feature usage statistics
- Export reports as CSV/PDF

### System Administration
- View system health and performance metrics
- Database statistics
- Cache hit rates
- API response times
- Error logs and debugging

### Audit Logs
- Security events log
- User actions tracking
- Admin actions audit trail
- Filter by date, user, event type

## Tech Stack

- **React 18** - UI framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **React Router** - Navigation
- **TanStack Query** - Data fetching and caching
- **Zustand** - State management
- **Recharts** - Data visualization
- **Vite** - Build tool

## Getting Started

### Prerequisites

- Node.js 20+
- Backend API running

### Installation

```bash
cd apps/admin
npm install
```

### Development

```bash
npm run dev
```

Opens at `http://localhost:5174`

### Build

```bash
npm run build
```

Output in `dist/` directory.

### Environment Variables

Create `.env.local`:

```env
VITE_API_URL=http://localhost:3000
VITE_WS_URL=ws://localhost:3000
```

## Project Structure

```
apps/admin/
├── src/
│   ├── components/      # Reusable UI components
│   │   ├── Dashboard.tsx
│   │   ├── UserList.tsx
│   │   ├── Analytics.tsx
│   │   └── ...
│   ├── hooks/           # Custom React hooks
│   │   ├── useAuth.ts
│   │   ├── useUsers.ts
│   │   └── ...
│   ├── lib/             # Utilities and helpers
│   │   ├── api.ts       # API client
│   │   ├── auth.ts      # Authentication
│   │   └── utils.ts     # Helper functions
│   ├── pages/           # Page components
│   │   ├── DashboardPage.tsx
│   │   ├── UsersPage.tsx
│   │   └── ...
│   ├── store/           # Zustand state stores
│   │   └── authStore.ts
│   ├── types/           # TypeScript definitions
│   │   └── index.ts
│   ├── App.tsx          # Main app component
│   ├── main.tsx         # Entry point
│   └── index.css        # Global styles
├── public/              # Static assets
├── index.html           # HTML template
├── package.json
├── tsconfig.json
├── vite.config.ts
└── tailwind.config.js
```

## Authentication

Admin dashboard requires authentication with Enterprise subscription tier.

```typescript
// Login
const response = await api.post('/api/auth/signin', {
  email: 'admin@teleprompt.pro',
  password: 'your-password',
});

// Check admin role
if (user.subscriptionTier !== 'enterprise') {
  // Redirect to unauthorized
}
```

## API Integration

All API calls go through centralized client:

```typescript
import { api } from './lib/api';

// Get users
const users = await api.get('/api/admin/users');

// Update user
await api.put(`/api/admin/users/${id}`, data);

// Delete user
await api.delete(`/api/admin/users/${id}`);
```

## Features Roadmap

### Phase 1 (Current)
- ✅ Dashboard overview
- ✅ User management
- ✅ Basic analytics
- ✅ Subscription management

### Phase 2
- [ ] Advanced analytics dashboards
- [ ] Content moderation tools
- [ ] Automated report generation
- [ ] Email notification system

### Phase 3
- [ ] Feature flags management
- [ ] A/B testing dashboard
- [ ] Customer support ticket system
- [ ] Billing and invoicing

### Phase 4
- [ ] ML model management
- [ ] Performance monitoring
- [ ] Custom dashboard widgets
- [ ] API key management

## Deployment

### Build for Production

```bash
npm run build
```

### Deploy to Vercel

```bash
vercel deploy
```

### Deploy to Netlify

```bash
netlify deploy --prod
```

### Docker

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build
EXPOSE 5174
CMD ["npm", "run", "preview"]
```

## Security

- All routes require authentication
- Enterprise subscription tier required
- CSRF protection enabled
- XSS prevention
- Rate limiting on API calls
- Audit logging for all admin actions

## Performance

- Code splitting by route
- Lazy loading of components
- Optimized bundle size (< 200KB gzipped)
- Server-side rendering support (future)
- Progressive web app (PWA) support

## Contributing

1. Create feature branch
2. Make changes
3. Run tests: `npm test`
4. Create pull request

## License

Proprietary - TelePrompt Pro
