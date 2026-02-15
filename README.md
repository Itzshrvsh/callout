# Callout - Smart Organization Request Management

A Flutter app with AI-powered request routing and Supabase backend for managing organizational requests and workflows.

## Features

✨ **Smart Request Routing**: Local LLM (Phi-3 via Ollama) analyzes requests and routes them to the appropriate approver
🏢 **Organization Management**: Create organizations, invite members, manage roles
📝 **Request Workflow**: Submit, approve, reject, or escalate requests with hierarchical routing
🔐 **Authentication**: Secure Supabase authentication
👥 **Role-Based Access**: Admin, CEO, Manager, Team Leader, and Member roles
📊 **Real-time Updates**: Live status tracking for requests

## Architecture

- **Frontend**: Flutter (Material Design 3)
- **Backend**: Supabase (PostgreSQL + Auth)
- **AI**: Local LLM via Ollama API (Phi-3 Mini recommended)
- **State Management**: Provider

## Prerequisites

Before running this app, you need:

1. **Flutter** (3.11.0 or higher)
   ```bash
   flutter --version
   ```

2. **Supabase Account**
   - Create a free account at [supabase.com](https://supabase.com)
   - Create a new project
   - Get your project URL and anon key

3. **Ollama** (for local LLM)
   ```bash
   # Install Ollama
   brew install ollama  # macOS
   
   # Start Ollama service
   ollama serve
   
   # Pull Phi-3 model (in a new terminal)
   ollama pull phi3
   ```

## Setup Instructions

### 1. Clone and Install Dependencies

```bash
cd /Users/itzshrvsh/Desktop/Flutter/callout
flutter pub get
```

### 2. Configure Environment Variables

Edit `.env` file and add your Supabase credentials:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
LLM_BASE_URL=http://localhost:11434
LLM_MODEL=phi3
```

### 3. Set Up Supabase Database

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Run the migration file: `supabase/migrations/00001_initial_schema.sql`
   - This creates all tables, RLS policies, functions, and triggers

### 4. Configure Email Templates (Optional)

In Supabase Dashboard → Authentication → Email Templates, customize:
- Join request notifications
- Request approval notifications
- Welcome emails

### 5. Run the App

```bash
# Make sure Ollama is running
ollama serve

# In another terminal, run Flutter
flutter run
```

## Usage Guide

### For Admins

1. **Create Organization**
   - Sign up / Sign in
   - Click "Create Org" button
   - Fill in organization details
   - You become the admin automatically

2. **Manage Members**
   - Go to Organization Dashboard
   - Click "Manage Members"
   - Approve/reject join requests
   - Assign roles to members

3. **Set Up Hierarchy**
   - Assign roles: CEO → Manager → Team Leader
   - Configure reporting structure

### For Members

1. **Join Organization**
   - Click "Join Org"
   - Search for organization
   - Send join request
   - Wait for admin approval

2. **Submit Request**
   - Go to Organization Dashboard
   - Click "Create Request"
   - Enter title and description
   - AI analyzes and classifies the request
   - Request routes to appropriate approver

3. **View Requests**
   - "My Requests": See all your submitted requests
   - "Pending Approvals": Requests waiting for your approval (if you're an approver)

### For Approvers

1. **Review Requests**
   - Go to "Pending Approvals"
   - Review request details
   - Choose action:
     - **Approve**: Accept the request
     - **Reject**: Decline with reason
     - **Escalate**: Send to higher authority

## Request Routing Logic

The AI-powered routing works as follows:

1. **Classification**: LLM analyzes request text and determines:
   - Type (leave, purchase, travel, etc.)
   - Importance (low, medium, high, critical)

2. **Initial Routing**: Routed to member's direct supervisor (reports_to)

3. **Escalation Path**:
   - Team Leader → Manager → CEO → Admin
   - Automatic routing if escalated
   - Based on importance and organizational hierarchy

## Database Schema

### Key Tables

- `users`: User profiles
- `organizations`: Organization details
- `organization_members`: User-org relationships with roles
- `join_requests`: Pending membership requests
- `requests`: All organizational requests
- `request_approvals`: Approval history

## LLM Integration

### Supported Models

- **Phi-3 Mini** (3.8B) - Recommended - 2.3GB
- **TinyLlama** (1.1B) - Smaller, less accurate
- Any Ollama-compatible model

### Fallback Behavior

If LLM is unavailable, the system uses keyword-based classification:
- Request type detection via keywords
- Default routing to supervisor
- Manual override available

## Troubleshooting

### LLM Not Working

```bash
# Check if Ollama is running
curl http://localhost:11434/api/tags

# Restart Ollama
killall ollama
ollama serve

# Verify model is ready
ollama list
```

### Supabase Connection Issues

1. Check `.env` file has correct credentials
2. Verify Supabase project is active
3. Check RLS policies are created

### Build Errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Building for Windows
Since the project uses macOS, you cannot build the Windows executable directly. A **GitHub Action** has been set up to build it automatically.

1. Push your changes to GitHub.
2. Go to the **Actions** tab in your repository.
3. Select **Build Windows Exe**.
4. Download the `callout-windows-exe` artifact from the latest run.

If you have a Windows machine:
```bash
flutter config --enable-windows-desktop
flutter build windows
```

## Project Structure

```
lib/
├── config/              # Supabase configuration
├── models/              # Data models
├── services/            # Business logic
│   ├── auth_service.dart
│   ├── llm_service.dart
│   ├── organization_service.dart
│   └── request_service.dart
├── screens/             # UI screens
│   ├── auth/
│   ├── organization/
│   └── requests/
└── main.dart           # App entry point
```

## Future Enhancements

- [ ] Push notifications
- [ ] Email notifications
- [ ] Request templates
- [ ] Advanced analytics
- [ ] Budget approval thresholds
- [ ] Department-based routing
- [ ] Request comments/chat
- [ ] File attachments

## License

MIT License

## Support

For issues or questions, please open an issue on GitHub.

---

Built with ❤️ using Flutter, Supabase, and AI
