# Architecture Analysis & Strategic Roadmap: Callout SaaS
**Version:** 1.0.0
**Status:** DRAFT (Post-MVP)
**Target:** 10,000+ Concurrent Users (DAU)

---

## 1. Executive Architecture Review

### Scalability: **Medium Risk**
- **Database (Supabase/PostgreSQL):** Excellent foundation. PostgreSQL scales vertically very well. For 10k users, the current single-instance setup is sufficient, provided indexes are optimal.
- **Compute (Flutter):** Client-side rendering is scalable.
- **AI Inference (Local Ollama):** **CRITICAL RISK**. Local inference on `localhost` is strictly for development. Mobile devices cannot reliably run 3B+ parameter models locally without significant battery drain, heat, and device compatibility issues (e.g., low-end Android).
  - *Constraint:* You cannot rely on users having hardware capable of running Phi-4.
  - *Fix:* Must move to **Hosted Inference** (Serverless GPU or Dedicated API).

### Security: **High Risk** (Currently)
- **RLS Simplified:** The decision to disable RLS on `requests` and `organizations` to bypass recursion effectively creates a **public database**.
  - *Impact:* Any authenticated user could technically curl the API and fetch *all* organization data.
  - *Fix:* Immediate priority to reimplement secure, non-recursive RLS using `SECURITY DEFINER` functions or materialized paths.
- **API Key Exposure:** If moving to hosted AI, keys must not be in the Flutter app. Use Supabase Edge Functions.

### Performance: **Good**
- **Latency:** Supabase (direct DB connection) is fast.
- **Bottleneck:** The "Real-time" aspect of LLM classification (1-2s) is acceptable but will degrade if the backend queue isn't managed.

### Multi-tenancy Isolation: **Logical Only**
- Currently relies on `organization_id` filters in queries. Without rigid RLS, this is "soft" multi-tenancy. Hard multi-tenancy (RLS) is required for Enterprise compliance (SOC2/HIPAA).

---

## 2. Production Risks & Architectural Bottlenecks

| # | Component | Bottleneck / Risk | Impact |
|---|---|---|---|
| 1 | **AI Layer** | Running locally (Ollama) | **Showstopper**. Mobile apps cannot connect to your laptop's localhost. |
| 2 | **Database Security** | RLS Disabled | **Critical**. Data leak inevitable. |
| 3 | **Hierarchy** | Fixed Role List | **Adoption Blocker**. Enterprises have custom titles (VP, Director, Lead) and matrix reporting. |
| 4 | **Notifications** | Polling / None | **Engagement Killer**. Approvals take days instead of minutes without push. |
| 5 | **Audit Logs** | Basic Table | **Compliance Risk**. Large enterprises need immutable, exportable, detailed logs. |

---

## 3. Enterprise-Grade Upgrades & Features

### 🏢 Adoption Boosters (High Value)
1.  **Dynamic Workflows (The "Workflow Engine"):**
    -   Instead of `Member -> Leader -> Manager`, allow admins to define:
        -   `If (Amount > $5k) -> CFO Approval`
        -   `If (Type == 'IT Security') -> CISO Approval`
    -   *Implementation:* A structured JSON schema column `workflow_config` in `organizations`.

2.  **SLA Tracking & Nudges:**
    -   "Request #123 is overdue by 4 hours."
    -   Auto-escalation if not approved in 24h.

3.  **Proxy Approvals (Out of Office):**
    -   "I am on leave, delegate my approvals to Sarah."

### 🧠 AI Improvements (Beyond Classification)
1.  **Duplicate Detection:** "Similar request found from 3 days ago by User B."
2.  **Policy Compliance Check:**
    -   Upload Org Policy PDF (RAG).
    -   AI checks request against policy. *e.g., "This travel request exceeds the $200 per diem limit."*
3.  **Sentiment/Tone Analysis:** Flag "High Frustration" requests for immediate HR attention.

### 🎨 UX for Heavy Users
-   **Batch Approvals:** Swipe right to approve 5 requests at once.
-   **Slack/Teams Integration:** Approve directly from a chat message (Interactive Buttons).

---

## 4. Redesigning the AI Layer

**Decision: Hosted Inference is Mandatory.**

### Architecture:
`Flutter App` -> `Supabase Edge Function` -> `LLM Provider (OpenAI/Anthropic/Anyscale)`

*Why?* Secure API keys, consistent latency, zero battery drain on user device.

### Strategy:
1.  **Hybrid Approach:** Use a tiny, on-device TFLite model for *instant* category guess (offline capable), then confirm with server-side LLM for complex extraction.
2.  **Confidence Scoring:**
    -   If AI Confidence > 90% -> Auto-route.
    -   If AI Confidence < 60% -> Ask user "Is this a **Legal** request?" (Human-in-the-loop).
3.  **Reinforcement Learning (RLHF-Lite):**
    -   Track every time a user *changes* the AI's suggested category.
    -   Store this pair: `(Description, Predicted: A, Actual: B)`.
    -   Fine-tune a smaller model (Phi-3/Llama-2-7b) weekly on this dataset to create a "Callout-Specific" model that learns org jargon.

---

## 5. Database Optimizations (PostgreSQL)

### 🛡️ RLS Hardening (Fixing Recursion)
Use **SECURITY DEFINER Functions** to bypass recursion limits safely.
-   Create a function `get_user_org_ids(user_uuid)` that returns a list of approved Org IDs.
-   Policy: `organization_id IN (SELECT get_user_org_ids(auth.uid()))`.
-   Index the function or use a materialized view for caching.

### ⚡ Indexing Strategy
-   **Partial Indexes:** `CREATE INDEX idx_pending_requests ON requests (current_approver_id) WHERE status = 'pending';` (Drastically speeds up the "My Approvals" dashboard).
-   **GIN Index:** On `requests.metadata` (JSONB) to allow searching within AI-extracted fields.

### 📦 Partitioning
-   Partition `requests` and `request_approvals` by `created_at` (Yearly). Move old years to "Archive" tables to keep active queries fast.

---

## 6. Performance & Infrastructure

### 🚀 Optimizations
1.  **Background Jobs (pg_net / Inngest):**
    -   When a request is created -> Trigger a job.
    -   Job: Sends Email + Push Notification + Updates Stats.
    -   *Why?* Don't block the UI while sending emails.
2.  **Read Replicas:** Separation of concerns. Use Read Replicas for the "Analytics Dashboard" queries so heavy reporting doesn't slow down operational approvals.

---

## 7. Monetization Strategy (SaaS)

| Tier | Functionality | Pricing Model | Defensibility |
|---|---|---|---|
| **Free / Starter** | Fixed Hierarchy, Basic AI, 5 Users | Free | Viral loop (inviting org members) |
| **Pro** | Custom Workflows, SLA Nudges, Exportable Logs | $10/user/mo | Workflow Stickiness |
| **Enterprise** | SSO (SAML), On-Premise AI Option, Dedicated Success Manager | Contact Sales | Security Compliance & Integrations |

**Defensibility:** The AI model fine-tuned on *your* specific organizational data becomes smarter than a generic LLM over time.

---

## 8. Staged Roadmap

### Phase 1: Production Ready (Fixing the Foundation)
-   [ ] **Security:** Re-enable and fix RLS policies (Strict Schema).
-   [ ] **AI:** Move AI logic to Supabase Edge Functions (OpenAI/Anthropic API).
-   [ ] **Notifications:** Implement FCM (Firebase Cloud Messaging) for Push.
-   [ ] **Storage:** Enable file attachments (receipts/docs).

### Phase 2: Enterprise Upgrade (Scale & Velocity)
-   [ ] **Dynamic Workflow Engine:** Build the JSON-based rule engine.
-   [ ] **Analytics:** "Time to Approve" reports & bottlenecks.
-   [ ] **Integrations:** Slack/Teams notification bot.
-   [ ] **Batch Actions:** Bulk approve/reject.

### Phase 3: AI Differentiation Layer (The "Smart" Era)
-   [ ] **Policy RAG:** "Chat with Org Policy" helper.
-   [ ] **Anomaly Detection:** AI flags suspicious requests.
-   [ ] **Auto-Approval:** AI automatically approves low-risk requests based on history (e.g., "$10 coffee" always approved).

---

*Verified by:* Senior Protocol Architect
*Date:* February 15, 2026
