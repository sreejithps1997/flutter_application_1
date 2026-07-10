# Workable Project Progress And Roadmap

This file is the local project memory for the Workable app. Read this before starting a new page or feature.

## Working Rule

- Before starting any new page or feature, check this file and inspect the relevant existing files first.
- Do not rebuild a page blindly if a foundation already exists.
- Prefer upgrading existing flows, connecting real Firestore data, and removing dummy behavior over adding duplicate screens.
- After finishing a meaningful change, update this file with what changed and what should happen next.

## Product Direction

Workable is evolving into a trusted local help marketplace.

Core idea:
- Customers can request normal services, repairs, pickup/drop/delivery help, emergency help, and future AI-assisted help.
- Workers can register, verify identity, define services/pricing/availability, receive jobs, complete work, receive payment, and request payouts.
- The long-term goal is a global-level app where people think of Workable first whenever they need help.

## Testing Backlog

Use this section as the master testing checklist when development pauses and the project enters the testing phase.

Testing rule:
- Whenever a new feature is added, add the important manual/functional/security tests here.
- During development, focused analyzer checks are still required for touched files.
- During testing phase, run these flows on real Android device/emulator with customer, worker, and admin accounts.

Smart Booking and AI tests:
- Smart Booking local flow:
  - customer opens Smart Booking from dashboard
  - customer opens Smart Booking from customer account
  - query: `Water is leaking under my kitchen sink and I need urgent help`
  - tap `Understand Need`
  - confirm local result detects plumbing/urgent-style need
  - confirm matched workers show when available
  - confirm Help Request option opens prefilled form
- Smart Booking to Help Request prefill:
  - confirm title, description, request type, and urgency are prefilled
  - create the help request
  - confirm Firestore stores `source: smart_booking`
  - confirm `sourceMetadata` stores query/category/urgency/demand/city context
  - after Deeper Diagnosis, confirm Help Request prefill uses AI category and urgency instead of only local category and urgency
  - after Deeper Diagnosis, confirm Help Request description includes AI summary, price range, and safety note when available
  - after Deeper Diagnosis, confirm `sourceMetadata.aiDiagnosis` is saved on the created Help Request
- Backend AI deeper diagnosis:
  - tap `Deeper Diagnosis`
  - confirm result shows `AI used` after OpenAI key and model are configured
  - confirm backend category, urgency, summary, questions, price range, and safety note display correctly
  - confirm AI confidence label displays as High confidence, Medium confidence, or Needs details
  - confirm recommended path label displays as compare workers, help request, or urgent help
  - if AI recommends `worker_booking`, confirm `View Workers` is the primary action
  - if AI recommends `help_request`, confirm `Create Help Request` is the primary action
  - if AI recommends `emergency`, confirm safety guidance appears and urgent help request requires confirmation
  - confirm Smart Helps count decreases only when real AI is used
  - confirm no quota is consumed when backend provider is not configured and fallback is returned
- AI quota/security:
  - use Deeper Diagnosis until quota finishes
  - confirm app shows quota exhausted message and local Smart Booking still works
  - confirm Firestore `aiUsage/{uid}/days/{yyyy-MM-dd}` updates through Cloud Functions
  - confirm client cannot manually write/increase `aiUsage`
  - confirm another user cannot read this user's `aiUsage`
- AI diagnosis cache:
  - run Deeper Diagnosis for a common request such as `AC not cooling`
  - run the same or very similar request again
  - confirm result shows cached AI state when cache is hit
  - confirm cached result does not reduce Smart Helps quota
  - confirm `aiUsage` records `cachedAiHits`
  - confirm client cannot manually create/update `smartBookingAiCache`
- AI provider failure:
  - test invalid/disabled API key in a safe dev project
  - confirm customer receives safe backend fallback instead of broken screen
  - confirm failed provider call is recorded in usage data
- Safety prompts:
  - test short circuit/electrical emergency query
  - test gas/fire/medical emergency query
  - confirm app gives safe guidance and does not pretend a worker is guaranteed
- Firestore core rules:
  - customer can read/update own `users/{uid}` and `customers/{uid}`
  - worker can read/update own `users/{uid}` and `workers/{uid}`
  - customer dashboard can still read worker marketplace profiles
  - customer can create booking for self
  - customer can read/update own bookings only
  - worker can read/update assigned bookings only
  - worker can accept open Help Request and linked booking still gets created
  - customer can create/read/update own Help Request
  - workers can read open Help Requests
  - unrelated user cannot read private customer/help/booking records
  - notification creation is owner/admin only after backend migration
- Firestore second rules batch:
  - customer can read/create own transactions
  - worker can read transactions assigned to them
  - worker can create/read own payout requests
  - admin can approve/reject/update payout requests
  - signed-in users can read reviews
  - customer can create/edit/delete own reviews
  - chat access is limited to chat participants
  - messages can be created only by the sender participant
  - typing status is limited to chat participants
  - verification queue can be created/read by submitting user and reviewed by admin
  - demandSignals and skills are no longer normal-user writable through explicit rules; customer demand creation, worker opportunity claims, and worker signup skill suggestions now go through Cloud Functions
- Backend notification migration:
  - help request accepted creates backend customer notification
  - linked help booking status changes create backend customer/worker notifications
  - linked help payment status changes create backend customer/worker notifications
  - demand approval creates backend notifications for interested customers, claimed workers, and matching workers
  - normal signed-in user cannot create notifications under another user's inbox
- Backend demand/skills migration:
  - pending manual testing; development/deploy completed, real app flow testing should be done later
  - customer unknown search creates/updates `demandSignals` through `recordSmartDemandSignal`
  - normal customer cannot directly create/update `demandSignals`
  - worker opportunity claim calls `claimDemandOpportunity`
  - claim updates worker `skills`, `services`, `serviceCategories`, and claimed signal metadata
  - normal worker cannot directly update `demandSignals`
  - worker signup Step 2 calls `suggestWorkerSignupSkill`
  - normal worker cannot directly create/update `skills`
  - admin can still review/approve demand signals and create approved skills
  - support requests, reported issues, referrals, verification docs, customer favorites, worker portfolio, and worker review reads still work after closed fallback rules
- Backend verification review consistency:
  - pending manual testing; development/deploy completed, real app flow testing should be done later
  - admin approves a pending verification document
  - backend creates the user verification notification
  - backend syncs worker visibility and verification tier
  - admin rejects a pending verification document with a reason
  - backend creates rejection history under `users/{uid}/verificationNotificationHistory`
  - backend creates an action-required verification notification
  - rejected verification notification routes to the identity verification screen

## Production Readiness Plan

Use this section before launching beyond private/internal testing. The app can continue feature development, but these items should be treated as launch blockers or near-launch blockers depending on risk.

Highest priority launch blockers:
1. Firestore production rules pass:
   - current `aiUsage` and `smartBookingAiCache` rules are protected from client writes
   - broad signed-in fallback has been closed
   - explicit rules now cover known active collections and subcollections
   - continue adding explicit rules before any new production collection is introduced
2. Admin access security:
   - admin screens currently depend mostly on app navigation/user type
   - Firestore rules must enforce admin-only writes for payment review, payout review, verification review, demand approval, category creation, and dispute actions
3. AI secret migration:
   - backend now prefers dotenv-style environment variables:
     - `OPENAI_API_KEY`
     - `OPENAI_MODEL`
   - legacy `functions.config().openai.key` fallback has been removed from code
   - Firebase legacy config can be unset after confirming env deploy works
4. Cloud Functions runtime/SDK upgrade:
   - current deploy warns Node.js 20 decommission date is October 30, 2026
   - upgrade Functions runtime/SDK carefully in a separate pass
   - verify all existing notification, booking, review, and Smart Booking functions after upgrade
5. App Check:
   - enable Firebase App Check for Android/iOS
   - enforce App Check on callable Functions after rollout
   - prevents basic scripted abuse of AI, booking, and Firestore surfaces

AI/Smart Booking production hardening:
- Move final quota enforcement fully backend-owned:
  - already done for AI calls
  - verify client cannot write `aiUsage`
- Restrict `smartBookingAiCache` reads if cached diagnosis text becomes sensitive:
  - current rule allows signed-in reads
  - safer future rule: no client reads, backend only
- Add abuse controls:
  - per-user hourly cap
  - repeated prompt cooldown
  - blocked prompt counter
  - suspicious usage logging
- Add cost controls:
  - global daily AI call cap
  - model override through backend config
  - admin dashboard for aiUsage totals
- Add data minimization:
  - cache normalized key and diagnosis only
  - avoid storing full raw customer request in cache/usage
  - review Help Request `sourceMetadata.aiDiagnosis` before launch for privacy

Marketplace production hardening:
- Payment trust:
  - verify UPI reported payment review states
  - verify cash confirmation states
  - verify admin approve/reject paths
  - verify no customer can mark another customer booking paid
- Worker payouts:
  - verify worker can request payout only from own available earnings
  - verify admin approve/reject only
  - verify payout method ownership
- Booking/help lifecycle:
  - verify worker can act only on assigned jobs
  - verify customer can act only on own bookings/help requests
  - verify linked help request booking conversion cannot be hijacked
- Notifications:
  - verify tap routing for booking/payment/chat/help/demand/verification
  - verify FCM token cleanup on logout
  - verify disabled notifications are respected

Recommended next production-readiness implementation:
1. Migrate OpenAI key from legacy `functions.config()` to safer environment/secrets approach.
2. Tighten `smartBookingAiCache` read rule to backend-only unless client read is truly needed.
3. Start full Firestore rules architecture collection by collection.

Completed immediate hardening:
- Tightened `smartBookingAiCache` client read access from any signed-in user to admin-only.
- Cloud Functions can still read/write the cache through Admin SDK.
- Added `.env` ignore rules at root and Functions level so real keys are not committed.
- Added `functions/.env.example`.
- Updated Functions OpenAI config loading to prefer `process.env.OPENAI_API_KEY` and `process.env.OPENAI_MODEL`.
- Removed legacy `functions.config().openai.*` fallback after env-based deploy succeeded.
- Added first core Firestore rules batch:
  - `users/{uid}` owner/admin writes
  - user subcollections for addresses, favorites, payment methods, FCM tokens, notifications
  - `customers/{uid}` owner/admin access
  - `workers/{uid}` marketplace read, owner/admin writes
  - `bookings/{bookingId}` customer/worker/admin access
  - `helpRequests/{requestId}` customer/assigned-worker/open-request/admin access

Resolved compatibility exception:
- Cross-user notification creation for booking/payment/help/demand flows moved to Cloud Functions.
- `users/{uid}/notifications` creation is now owner/admin only.
- Added second Firestore rules batch:
  - `transactions/{transactionId}` customer/worker/admin reads, customer/admin creates, admin updates
  - `payoutRequests/{requestId}` worker/admin reads, worker/admin creates, admin updates
  - `reviews/{reviewId}` signed-in reads, customer/admin writes
  - `chats/{chatId}` participant/admin access
  - `chats/{chatId}/messages/{messageId}` participant access and sender-only message creation
  - `chats/{chatId}/status/{statusId}` participant typing/status access
  - `adminVerificationQueue/{requestId}` submitter/admin reads, submitter/admin creates, admin updates
  - `demandSignals/{signalId}` signed-in read, admin/client writes only
  - `skills/{skillId}` signed-in read, admin/client writes only
- Deployed second rules batch successfully after removing one unused helper warning.

Completed demand/skills backend migration:
- Added Cloud Functions:
  - `recordSmartDemandSignal`
  - `claimDemandOpportunity`
  - `suggestWorkerSignupSkill`
- Smart Demand customer searches now create/update demand signals through backend callable logic.
- Worker Opportunity claims now update worker profile/category arrays and demand signal claim metadata through backend callable logic.
- Worker signup Step 2 now records selected skill suggestions through backend callable logic.
- Closed the broad Firestore fallback rule and added explicit rules for known remaining active paths:
  - `users/{uid}/identityVerification`
  - `users/{uid}/verificationNotificationHistory`
  - `customers/{uid}/favoriteWorkers`
  - `workers/{uid}/portfolio`
  - `workers/{uid}/reviews`
  - `support_requests`
  - `reported_issues`
  - `referrals`

Remaining security hardening notes:
- Deploy the latest Functions and Firestore rules.
- Test all major customer, worker, admin, help, booking, support, referral, verification, and demand flows after fallback closure.
- Future new collections must receive explicit rules before use.
- Enable Firebase App Check later for callable Functions and Firestore.

## Backend Notification Creation Migration

Completed:
- Added Cloud Functions:
  - `notifyOnHelpRequestAccepted`
  - `notifyOnLinkedHelpBookingUpdate`
  - `notifyOnDemandApproved`
- Existing Cloud Functions already cover:
  - booking creation notification
  - chat message notification
  - worker review notification
  - push delivery from notification document creation
- Removed client-side cross-user notification creation from:
  - linked Help Request booking milestones
  - linked Help Request payment updates
  - Help Request accepted flow
  - admin demand approval flow
- Tightened Firestore notification creation:
  - users can create notifications only in their own inbox
  - admins can create notifications
  - backend Cloud Functions create cross-user notifications through Admin SDK
- Deployed Functions and Firestore rules successfully.

Known remaining notification note:
- Verification review notifications now move through backend when `adminVerificationQueue` status changes.
- Some owner-only client notification helper methods remain for local preference/inbox operations; review them later if we want every notification path to be backend-created.

Recommended next hardening step:
- Deploy and manually test the demand/skills and verification backend migrations, then continue with App Check and remaining admin backend consistency work.

Next OpenAI config migration action:
1. Deploy Functions after fallback removal:
   - `firebase deploy --only functions`
2. Confirm Smart Booking `Deeper Diagnosis` works.
3. Optionally unset old Firebase Functions config after confirmation.

## Innovation Backlog

Use this section to capture high-value ideas that should be built after the current cleanup and architecture work. If a new idea appears in the middle of another task, add it here instead of interrupting the active work.

Build timing rule:
- Do not add large AI/growth features before the remaining route/legacy cleanup and the first Clean Architecture + Riverpod pilot.
- Build new large features as feature-first modules after the architecture pattern is proven.
- Each idea should later be converted into a short product spec before implementation.

AI features to add:
- AI Service Diagnosis:
  - customer types, speaks, or uploads photo/video
  - AI identifies likely issue, urgency, service category, estimated price range, tools needed, and best worker type
  - goal: customer does not need to know whether they need plumber, electrician, carpenter, appliance repair, general helper, delivery, pickup, or care support
- Smart Booking Assistant:
  - chat-style flow asks only necessary questions
  - captures issue, urgency, photos, schedule, address, budget, and notes
  - creates booking or generic help request automatically
- Smart Worker Matching:
  - ranks workers by location, availability, skill fit, rating, similar past jobs, price, response speed, verification level, and customer preference
  - output should feel like "best match for your need", not random browsing
- Emergency Mode:
  - for urgent water leak, power issue, locked door, elder/baby support, unsafe situations, or critical pickup/drop
  - prioritizes nearby, available, verified, fast-response workers
- AI Price Estimate:
  - shows expected price range, possible extra charges, and why the price may vary
  - goal: reduce customer-worker payment arguments
- Work Quality Verification:
  - customer/worker can upload before/after photo or short video
  - AI assists admin/customer by checking whether visible proof matches the service and whether dispute review is needed
  - AI should support decisions, not make final high-stakes decisions automatically
- AI Worker Assistant:
  - improves worker profile title, service descriptions, portfolio captions, pricing suggestions, and professional replies
  - explains why profile is not visible and what to fix
  - suggests new skills/categories based on market demand
- AI Customer Support:
  - customer asks "Where is my worker?", "Payment not updated", "How do I cancel?", "Worker did not complete work"
  - AI checks booking/payment/support status and gives direct actions
- Predictive Maintenance:
  - reminds customers based on history, season, repeated problems, and city events
  - examples: AC cleaning before summer, plumbing inspection after repeated repairs, festival cleaning, appliance service reminder
- Trust Score Labels:
  - AI-assisted worker trust labels from verification, rating consistency, completion rate, cancellation rate, dispute rate, and response time
  - examples: Highly Reliable, Fast Responder, Best for Urgent Jobs, Budget Friendly, Premium Expert

Growth and marketplace innovation:
- Smart Demand Discovery:
  - customer searches for any job/help need
  - if category exists, show likely category and matching workers
  - if category does not exist, create a demand signal instead of silently failing
  - demand signal stores search phrase, guessed category, location/city, urgency, customer count, and status
- New Category Demand Engine:
  - repeated unknown searches become candidate categories
  - admin can merge similar demand signals and approve official categories
  - example: fish tank repair, aquarium motor repair, aquarium cleaning -> Aquarium Services
- Dynamic Worker Signup Categories:
  - worker signup/service selection should not depend only on hardcoded predefined categories
  - approved customer demand should become visible in worker signup and professional profile category selection
  - source of truth should be Firestore `skills` or a future `serviceCategories` collection, not local static lists
  - categories should have status such as draft, demand_detected, admin_approved, active, hidden, deprecated
  - customer unknown searches create demand signals first, not instant public categories
  - admin reviews/merges/approves demand into official categories
  - once approved, new category appears in:
    - worker signup skill/category step
    - worker professional profile service categories
    - worker opportunity feed
    - customer search/category filters
  - category records should include display name, aliases, parent category, icon/key, city availability, required verification level, pricing guidance, and created-from-demand metadata
  - worker signup should show smart sections:
    - Popular near you
    - New customer demand
    - Core services
    - Other services
  - search inside worker signup should allow workers to find new/niche categories quickly
  - if a worker cannot find their category, they can suggest it; that suggestion becomes a demand/admin review signal
  - intelligent behavior:
    - rank categories by city demand, worker profile fit, search count, and recent customer requests
    - suggest related categories to workers based on selected skills
    - notify existing workers when a related new category becomes active
    - avoid duplicate categories by alias/keyword matching before admin approval
  - build rule:
    - do this after the current AI Smart Booking polish and after the service category architecture is cleaned
    - do not let raw customer text instantly become public worker categories without admin approval
- Worker Opportunity Feed:
  - workers see new customer demand near them
  - worker can tap "I can do this" to add category/skill to profile
  - related workers get suggested opportunities based on existing skills
- Viral Worker Recruitment:
  - if no worker exists, customer or workers can share a demand link to WhatsApp/social media
  - share message should recruit people who can do that job into Workable
  - goal: zero-cost worker acquisition from real demand
- Customer Waitlist:
  - if a service is unavailable, customer can request notification when it becomes available in their area
- Demand Heat Map:
  - admin sees which jobs customers search for by city/area
  - supports launch planning city by city
- Share/Referral Growth System:
  - real invite links for customers and workers
  - share app, share job demand, share worker profile, share referral code
  - reward logic can be added after payment/trust systems stabilize
- Daily Use Hooks:
  - daily local help feed, maintenance reminders, saved family/home tasks, upcoming service reminders, worker opportunity alerts
  - goal: users open Workable regularly, not only during emergencies
- AI Cost Control And Smart Help Quota:
  - do not expose "tokens" to users; show friendly "Smart Helps"
  - give customers a small free daily quota, for example 3 Smart Helps per day
  - manual search remains free even when AI quota is finished
  - call AI only when local keyword/category matching is unclear, confidence is low, photo/voice is used, or no category exists
  - cache common diagnosis results so repeated requests like AC not cooling or water leak do not always call AI
  - track daily usage in a backend-owned structure such as `aiUsage/{uid}/days/{yyyy-MM-dd}`
  - track AI calls, estimated tokens, repeated prompts, failed prompts, and booking conversion after AI
  - if customer completes a booking, grant bonus Smart Helps or recover AI cost through normal platform/service fee instead of showing an "AI token fee"
  - after quota ends, offer gentle options: continue manual search, unlock extra Smart Helps, or get bonus Smart Helps after a completed booking
  - workers should also have limited AI quota for profile improvement, pricing suggestions, and professional replies
  - abuse protection should stop repeated useless prompts by asking for clearer details or falling back to local guidance

Recommended first new feature after architecture pilot:
- Smart Demand Discovery + Smart Booking Assistant.
- Reason: directly supports the product promise: "Whatever help you need, ask Workable first."

## Design System

Completed:
- Added shared design foundation in `lib/core/theme/workable_design.dart`.
- App theme in `main.dart` uses `WorkableDesign.lightTheme` and `WorkableDesign.darkTheme`.
- High contrast and font size settings are preserved through app-wide theme behavior.
- Started moving screens away from one-off colors and old deep-purple styling.
- Added first shared UI component layer in `lib/widgets/workable_ui.dart`:
  - `WorkablePageHeader`
  - `WorkableSectionCard`
  - `WorkableStatusPill`
  - `WorkableEmptyState`
  - `WorkableInfoRow`
- Customer bookings screen now uses the shared UI layer and `WorkableDesign`.

Important design direction:
- Use `WorkableDesign.canvas`, `surface`, `ink`, `muted`, `primary`, `accent`, `success`, `warning`, `danger`.
- Prefer 8px card radius unless a specific local component needs another shape.
- Avoid fake/dummy actions.
- Use real status, real Firestore data, clear empty states, and consistent cards/buttons.

## Clean Architecture + Riverpod Pilot

Completed:
- Started the first feature-first architecture migration with Notifications.
- Added `ProviderScope` at app startup in `main.dart`, so Riverpod providers can be used across the app.
- Created the Notifications feature module:
  - `lib/features/notifications/domain/workable_notification.dart`
  - `lib/features/notifications/data/notification_repository.dart`
  - `lib/features/notifications/presentation/notification_providers.dart`
  - `lib/features/notifications/presentation/notifications_screen.dart`
- Kept the old route/import stable:
  - `lib/screens/notifications_screen.dart` now exports the feature screen.
  - `/customer/notifications` continues to work without route changes.
- Preserved existing real behavior:
  - Firestore stream from `users/{uid}/notifications`
  - unread-only filter
  - unread count
  - mark single notification read
  - mark all notifications read
  - empty/loading/error states
- Improved architecture shape:
  - screen no longer calls Firebase directly
  - repository owns Firestore/Auth access
  - providers own stream/filter/read state
  - UI consumes `WorkableNotification` model
- Focused analyzer passed for `main.dart`, the new notification feature files, and the compatibility wrapper.

Architecture pattern to reuse:
- For future migrations, use:
  - `lib/features/<feature>/domain`
  - `lib/features/<feature>/data`
  - `lib/features/<feature>/presentation`
- Keep old `lib/screens/...` files as small compatibility wrappers while routes are still centralized in `main.dart`.
- Migrate one real feature at a time, run focused analyzer, then update this file.

Recommended next architecture feature:
- Smart Demand Discovery foundation can now be built as a new feature-first module after any small remaining cleanup.
- If we want one more low-risk migration first, use customer support/inbox because it follows a similar repository/provider/screen pattern.

## Smart Demand Discovery

Completed:
- Added the first feature-first Smart Demand Discovery backbone.
- Created the Smart Demand module:
  - `lib/features/smart_demand/domain/demand_discovery_result.dart`
  - `lib/features/smart_demand/data/demand_discovery_repository.dart`
  - `lib/features/smart_demand/presentation/demand_discovery_providers.dart`
  - `lib/features/smart_demand/presentation/smart_demand_search_screen.dart`
- Kept the old search route/import stable:
  - `lib/screens/search_screen.dart` now exports the new feature screen.
  - `/search` continues to work through the existing route in `main.dart`.
- Customer search now does more than direct worker filtering:
  - accepts natural help phrases like water leak, pickup, AC not cooling, cleaning, elder support
  - guesses a likely category through local keyword rules
  - searches visible marketplace workers first
  - ranks worker results by service fit, rating, and completed jobs
  - opens `WorkerListScreen` when workers are found
- If no worker exists:
  - writes or updates a real Firestore `demandSignals/{city_query}` document
  - stores search phrase, normalized phrase, guessed category, city, status, search count, customer ids, source, admin action, and timestamps
  - shows the customer a "Demand captured" state instead of a dead empty search
  - supports copying a worker recruitment/share message
  - links customer to the existing generic help request flow
- Focused analyzer passed for `main.dart`, the Smart Demand feature files, and the compatibility wrapper.

Important current limitations:
- Category guessing is local keyword logic, not AI yet.
- Native social share is still planned; current version copies a share/recruitment message.
- Worker opportunity feed is not built yet.
- Admin demand review/merge/approve screen is not built yet.

Recommended next steps:
1. Add worker-side Opportunity Feed:
   - workers see open `demandSignals`
   - workers can tap "I can do this"
   - selected category/skill can be added to worker profile after confirmation
2. Add admin Demand Review Center:
   - merge similar demand signals
   - approve new official categories
   - monitor demand by city/search count
3. Later replace local keyword guessing with AI Service Diagnosis:
   - text/audio/photo input
   - urgency detection
   - price estimate
   - smarter category mapping

## Worker Opportunity Feed

Completed:
- Added worker-side Opportunity Feed as a feature-first module:
  - `lib/features/worker_opportunities/domain/worker_opportunity.dart`
  - `lib/features/worker_opportunities/data/worker_opportunity_repository.dart`
  - `lib/features/worker_opportunities/presentation/worker_opportunity_providers.dart`
  - `lib/features/worker_opportunities/presentation/worker_opportunity_feed_screen.dart`
- Added route:
  - `/worker/opportunities`
- Added entry points:
  - Worker dashboard quick action now opens Opportunities.
  - Worker account Business section now includes Opportunity Feed.
- Feed behavior:
  - streams open `demandSignals`
  - prioritizes high-search demand and recent demand
  - shows customer search phrase, guessed category, city, search count, and last-searched date
  - workers can tap "I can do this"
  - claim action updates worker `skills`, `services`, and `serviceCategories`
  - claim action records worker id under the demand signal
  - already-claimed opportunities show as added
- Focused analyzer passed for:
  - Worker Opportunity feature files
  - `worker_account_screen.dart`
  - `worker_dashboard_screen.dart`
  - `main.dart`

Important current limitations:
- Opportunity claims add skill/category to profile, but do not yet validate pricing/experience.
- Workers do not yet get push notifications for new demand.
- Admin Demand Review Center is still needed to approve/merge new categories.

## Admin Demand Review Center

Completed:
- Added Admin Demand Review Center as a feature-first module:
  - `lib/features/admin_demand/domain/admin_demand_signal.dart`
  - `lib/features/admin_demand/data/admin_demand_repository.dart`
  - `lib/features/admin_demand/presentation/admin_demand_providers.dart`
  - `lib/features/admin_demand/presentation/admin_demand_review_screen.dart`
- Added route:
  - `/admin-demand-review`
- Added admin dashboard shortcut:
  - Verification Queue app bar now includes Demand Review.
- Admin can now review real `demandSignals`:
  - filter by open, approved, merged, rejected, or all
  - see search phrase, guessed category, city, search count, interested customers, worker interest, and last searched date
  - approve demand into an official category
  - merge demand into an existing/new category
  - reject unsuitable demand with reason
- Approval behavior:
  - updates `demandSignals/{id}` with approved status and review metadata
  - creates/updates `skills/{categoryName}` so customer dashboard filters and worker signup can see the approved category
- Merge behavior:
  - marks signal as merged and stores the reviewed category
- Reject behavior:
  - marks signal as rejected and stores rejection reason
- Focused analyzer passed for:
  - Admin Demand feature files
  - `admin_verification_dashboard.dart`
  - `main.dart`

Important current limitations:
- Admin review does not yet bulk-merge similar demand signals.
- There is not yet a city/category heat map chart.

## Demand Notification Loop

Completed:
- Added marketplace notification support to `NotificationService`:
  - writes to the same `users/{uid}/notifications` inbox used by the notifications feature
  - supports notification category, status, action-needed state, and metadata
- Admin category approval now sends inbox notifications:
  - customers who searched for the demand are notified that the approved category is available
  - workers who claimed the opportunity are notified that the category is approved
  - workers already matching the approved category through `skills` or `serviceCategories` are notified
- Approval notification metadata includes:
  - demand signal id
  - approved category name
  - original search phrase
- Cleaned old `print` diagnostics in `notification_service.dart` to `debugPrint`.
- Focused analyzer passed for:
  - `notification_service.dart`
  - `admin_demand_repository.dart`
  - `admin_demand_review_screen.dart`

Important current limitations:
- This creates in-app inbox notifications; actual push delivery still depends on server/Cloud Functions or a trusted backend using saved FCM tokens.
- Notification targeting is basic:
  - interested customers
  - claiming workers
  - workers with exact matching skill/category
- Later AI/category normalization can improve targeting for similar skills.

## Cloud Functions Push Delivery

Completed:
- Added backend push delivery trigger in `functions/index.js`.
- New Cloud Function:
  - `sendPushOnNotificationCreate`
  - watches `users/{uid}/notifications/{notificationId}`
  - sends FCM push when any in-app notification is created
- Push delivery behavior:
  - respects `users/{uid}.notificationsEnabled == false`
  - reads current app token from `users/{uid}.fcmToken`
  - also supports future multi-device tokens from `users/{uid}/fcmTokens/{tokenDoc}`
  - sends notification title/body from the notification document
  - sends data payload including notification id, type, status, category, requiresAction, demandSignalId, categoryName, bookingId, and documentId
  - marks the notification document with `pushStatus`, `pushSentAt`, `pushSuccessCount`, and `pushTargetCount`
  - removes invalid/expired tokens when Firebase reports token errors
- Verification:
  - `node --check index.js` passed in `functions`
  - `npm run lint` passed in `functions`

Deployment note:
- Push backend will run only after deployment:
  - `firebase deploy --only functions`

Important current limitations:
- Existing app currently saves one root `fcmToken`; multi-device token collection is supported by the function but the Flutter app does not yet write multiple device tokens.
- Existing chat/booking/review functions still send direct pushes separately; if those flows also start creating in-app notifications later, duplicate push prevention should be added.

## Multi-Device FCM Token Storage

Completed:
- Upgraded Flutter token saving in `NotificationService`.
- App now keeps backward compatibility by still writing:
  - `users/{uid}.fcmToken`
- App now also writes per-device token records:
  - `users/{uid}/fcmTokens/{token}`
- Token document stores:
  - token
  - platform
  - enabled
  - createdAt
  - updatedAt
- Token refresh listener now updates both the root token and device-token document through one shared helper.
- Turning notifications off now removes the current device token from `users/{uid}/fcmTokens` before deleting the local FCM token.
- This matches the deployed Cloud Function push delivery support for multi-device users.
- Focused analyzer passed for `notification_service.dart`.

Important current limitations:
- Logout does not yet explicitly remove the current device token.
- Device metadata is basic; later we can add app version, device model, locale, and last active time.

## Logout Token Cleanup

Completed:
- Added public `NotificationService.removeCurrentDeviceToken()`.
- Shared account logout now removes the current device FCM token before `FirebaseAuth.signOut()`.
- Worker dashboard logout now removes the current device FCM token before `FirebaseAuth.signOut()`.
- `AuthService.signOut()` now removes the current device FCM token before Google/Firebase sign-out.
- This prevents signed-out devices from remaining in `users/{uid}/fcmTokens/{token}`.
- Focused analyzer result:
  - token cleanup files compile
  - `auth_service.dart` still has older existing info warnings from production `print` calls and deprecated `fetchSignInMethodsForEmail`

Important current limitations:
- Some direct sign-out calls used during signup/login mismatch flows still call Firebase Auth directly; these are account-flow resets, not normal user logout.
- A later auth-service cleanup should replace old `print` diagnostics with `debugPrint` or structured logging.

## Notification Tap Routing

Completed:
- Added shared notification routing helper:
  - `lib/services/notification_navigation_service.dart`
- Added global app navigator key for notification-driven navigation.
- Push tap handling now supports:
  - background notification taps through `FirebaseMessaging.onMessageOpenedApp`
  - terminated-app initial notification through `FirebaseMessaging.instance.getInitialMessage`
  - foreground local notification taps through `flutterLocalNotificationsPlugin.initialize`
- Foreground local notifications now include encoded `message.data` as tap payload.
- Prevented duplicate foreground/tap Firebase Messaging listeners during app rebuilds.
- In-app notifications now carry routing metadata from Firestore.
- In-app notification cards now:
  - mark unread notification as read
  - route to the correct screen after tap
- Current routing behavior:
  - `demand_category_approved` / `demand_discovery` -> Smart Search
  - `worker_category_opportunity` / `worker_opportunity` -> Worker Opportunity Feed
  - verification notifications -> Identity Verification
  - payment notifications with booking id -> Customer Payment
  - booking notifications with booking id -> customer booking detail or worker job detail based on current user/worker id
  - help request notifications -> Generic Help Request
  - unknown notification types -> customer notifications inbox
- Focused analyzer passed for:
  - `main.dart`
  - `notification_navigation_service.dart`
  - notification domain/data/presentation files

Important current limitations:
- Older direct Cloud Functions for chat/booking/review currently send push notifications with little/no data payload, so those taps may fall back to the notification inbox until those functions are upgraded.
- Chat-specific routing needs chat id / other user id / user role in push data before it can open a specific chat thread reliably.

## Unified Notification Document Flow

Completed:
- Converted older direct Cloud Functions to the unified notification-document architecture.
- Updated `functions/index.js`:
  - `sendMessageNotification` now creates `users/{receiverId}/notifications/{id}` instead of directly sending push
  - `notifyWorkerOnBooking` now creates `users/{workerId}/notifications/{id}` instead of directly sending push
  - `notifyWorkerOnReview` now creates `users/{workerId}/notifications/{id}` instead of directly sending push
  - `sendPushOnNotificationCreate` remains the single push delivery function
- Added shared `createUserNotification` helper in Cloud Functions.
- Added push data fields for:
  - chatId
  - chatWithId
  - chatWithName
  - userRole
  - reviewId
  - workerId
- Flutter notification routing now supports:
  - chat notifications -> `ChatScreen`
  - review notifications with booking/worker id -> `CustomerBookingReviewScreen`
- In-app notification routing metadata now includes chat/review fields.
- Verification:
  - `node --check index.js` passed in `functions`
  - `npm run lint` passed in `functions`
  - focused Dart analyzer passed for notification router/repository/screen/main

Deployment note:
- Deploy Cloud Functions again after this change:
  - `firebase deploy --only functions`

Important current limitations:
- Existing notifications already created before this change will not magically gain new routing metadata.
- Review routing needs both `bookingId` and `workerId`; if either is missing, it falls back to other routing/default inbox behavior.

## Entry And Auth Flow

Completed:
- Redesigned splash screen.
- Removed broken old splash navigation to `/login`.
- Main app still controls transition to user type selection.
- Redesigned user type selection screen.
- Removed broken `/browse-services` action because route was not registered.
- Redesigned customer auth choice screen.
- Redesigned worker auth choice screen.
- Redesigned customer login screen.
- Redesigned worker login screen.
- Preserved email-or-phone login behavior.
- Preserved customer/admin routing from customer login.
- Preserved worker routing to worker dashboard.
- Removed debug print noise from redesigned login screens.

Files touched:
- `lib/screens/splash_screen.dart`
- `lib/screens/user_type_selection_screen.dart`
- `lib/screens/customer_auth_screen.dart`
- `lib/screens/worker_auth_screen.dart`
- `lib/screens/customer_login_screen.dart`
- `lib/screens/worker_login_screen.dart`

## Customer Foundations

Completed:
- Added real customer notifications inbox at `/customer/notifications`.
- Notifications screen reads Firestore notifications.
- Added mark read / mark all read behavior.
- Notifications screen UI polish completed:
  - imported `WorkableDesign` and shared empty state
  - app shell, notification cards, unread state, status pills, action-needed state, and empty states now use shared design tokens
  - preserved Firestore inbox stream, unread filter, mark single read, and mark all read behavior
- Messages screen UI polish completed:
  - imported `WorkableDesign` and shared empty state
  - app shell, search field, filter chips, conversation cards, unread badges, and empty states now use shared design tokens
  - preserved chat stream, search, filters, unread counts, route-based customer/worker role handling, and chat navigation
- Chat screen UI polish completed:
  - imported `WorkableDesign` and shared empty state
  - app shell, header, message bubbles, location message card, booking context bar, typing indicator, quick replies, empty state, and input bar now use shared design tokens
  - preserved text send, image send, location send, quick replies, typing status, read marking, booking detail navigation, and chat service integration
- Focused analyzer passed for `notifications_screen.dart`, `messages_screen.dart`, and `chat_screen.dart`.
- Fixed customer booking detail access so old bookings still open.
- If worker is unavailable, customer sees a warning but existing booking detail still opens.
- Fixed `widget_test.dart` analyzer issue.
- Added analyzer exclude for stale nested project folder.
- Connected customer notification toggle to real notification preference/token behavior.
- Connected customer location toggle to Android/iOS permission behavior.
- Made accessibility settings affect app UI:
  - font size
  - high contrast
- Connected customer account stats to real Firestore counts where possible.
- Customer account page UI polish completed:
  - shell now uses `WorkableDesign.canvas`
  - imported and applied `WorkableDesign` tokens to main visible account blocks
  - cleaned wallet/rewards/rating display to ASCII-safe `Rs`, `star`, and `-`
  - cleaned active booking banner separator and action text
  - quick action cards, section cards, logout button, snackbars, and photo options moved closer to shared design tokens
  - removed unused membership color helper
  - focused analyzer passed for `base_account_screen.dart` and `customer_account_screen.dart`
- Checked and cleaned multiple dummy customer-side pages.
- Rechecked message portion after earlier work.
- Customer account/money child screen polish completed:
  - `favorite_workers_screen.dart` rebuilt with shared `WorkableDesign`:
    - removed separate dark/purple one-off theme
    - preserved Firestore favorite worker collection
    - loads saved worker profiles from `workers`
    - search and skill filters remain
    - primary action opens worker profile/booking path
    - removed corrupted rupee/display text in visible cards
    - added shared empty/error states and remove favorite confirmation
  - `address_management_screen.dart` upgraded:
    - added shared page header and canvas shell
    - preserved Firestore address loading, selection mode, edit/delete/default behavior
    - fixed hardcoded default count; now counts real default addresses
    - added no-address empty state
    - added safer mounted checks around async refreshes
  - `add_new_address_screen.dart` upgraded:
    - added shared page header and canvas shell
    - preserved map picker/geocoding and Firestore address shape
    - added save lock/loading state
    - added validation for label, full address, area, pincode, and primary contact
    - cleaned map picker and type chip styling toward shared design tokens
  - `payment_methods_screen.dart` polished:
    - added shared page header and canvas shell
    - preserved real UPI alias storage under `users/{uid}/paymentMethods`
    - preserved default method, delete, quick pay, auto-pay, and biometric preference behavior
    - kept card/bank storage marked as future gateway integration instead of pretending it works
  - `wallet_credits_screen.dart` polished:
    - added shared page header and canvas shell
    - preserved Firestore transaction-based wallet balance, credit, spend, and analytics calculations
  - `transaction_history_screen.dart` polished:
    - added shared page header and canvas shell
    - preserved Firestore transaction stream, filters, search, and worker/customer owner-field support
  - Focused analyzer passed for all six customer account/money child screens.
- Customer profile/security child screen polish completed:
  - `change_password_screen.dart` rebuilt with shared `WorkableDesign`:
    - preserved real Firebase re-authentication and password update flow
    - writes `passwordUpdatedAt` and `securityUpdatedAt` to Firestore
    - added stronger password requirements:
      - at least 8 characters
      - uppercase
      - lowercase
      - number
      - different from current password
    - added secure page header, password standard card, loading state, and cleaner error handling
  - `my_reviews_screen.dart` polished:
    - preserved real Firestore review stream and completed-booking pending review stream
    - preserved search, filters, edit/delete, and write-review navigation
    - added shared page header and canvas shell
    - tokenized stats/review/pending-review styling
    - replaced visible corrupted review guideline bullets with clean ASCII guidance
  - `personal_information_screen.dart` targeted polish:
    - preserved Firestore profile load/save behavior
    - preserved identity verification, add-address, and change-password navigation
    - added shared page header and canvas shell
    - section cards now use shared `WorkableSectionCard`
    - tokenized profile completion/progress and profile avatar color
    - save now writes `profileUpdatedAt`
  - Focused analyzer passed for all three customer profile/security child screens.
- Support/customer utility screen polish completed:
  - `report_issue_screen.dart` rebuilt as a real issue intake screen:
    - uses shared `WorkableDesign`, `WorkablePageHeader`, `WorkableSectionCard`, and `WorkableInfoRow`
    - writes customer issue reports to `reported_issues`
    - stores issue type, description, optional booking id, local attachment flag, status, priority, and timestamps
    - safety issues are marked high priority
    - keeps attachment handling honest by previewing local image selection without pretending Firebase Storage upload exists yet
  - `referral_programme_screen.dart` rebuilt as a real invite/referral screen:
    - generates or reuses a customer referral code on `users/{uid}`
    - reads referral rows from `referrals` where `referrerId == uid`
    - shows real completed, pending, and earned reward counts from Firestore
    - supports copying invite text and referral code through Clipboard
    - keeps native share plugin integration as a future enhancement instead of fake sharing
  - `repeat_booking_screen.dart` polished:
    - preserved real Firestore completed-booking query and frequent-service calculation
    - added shared page header, card styling, empty states, and design tokens
    - keeps repeat booking navigation prefilled with same worker or same service details
    - cleaned visible rupee text to ASCII-safe `Rs`
    - added mounted guards around async loading
  - `help_support_screen.dart` rebuilt as a real support hub:
    - removed old commented-out support implementation and static-only active UI
    - added searchable FAQ/help topics
    - added quick actions to report issue and repeat booking
    - writes support tickets to `support_requests`
    - stores category, subject, message, status, priority, source, and timestamps
    - safety category is marked high priority
  - Focused analyzer passed for all four support/customer utility screens.
- Review/rating utility screen cleanup completed:
  - `customer_reviews_screen.dart` is now a compatibility wrapper around the already-polished `MyReviewsScreen`
    - removes the old duplicate deep-purple review list
    - keeps `/customer-reviews` route working
    - avoids maintaining two separate customer review experiences
  - `ratings_reviews_screen.dart` rebuilt from dummy hardcoded reviews into a real Firestore-backed rating dashboard:
    - reads `reviews` where `workerId` matches the signed-in user
    - shows average rating, total reviews, positive quality signal, rating distribution, recent feedback, service/date, and review tags
    - uses shared `WorkableDesign`, `WorkablePageHeader`, `WorkableSectionCard`, `WorkableStatusPill`, and `WorkableEmptyState`
    - removes fake customer names and hardcoded review comments
  - Focused analyzer passed for both review/rating utility screens.

Important files:
- `lib/screens/notifications_screen.dart`
- `lib/screens/customer_bookings_screen.dart`
- `lib/screens/customer_booking_detail_screen.dart`
- `lib/screens/account/customer_account_screen.dart`
- `lib/screens/payment_methods_screen.dart`
- `lib/screens/wallet_credits_screen.dart`
- `lib/screens/transaction_history_screen.dart`
- `lib/screens/favorite_workers_screen.dart`
- `lib/screens/address_management_screen.dart`
- `lib/screens/add_new_address_screen.dart`
- `lib/screens/personal_information_screen.dart`
- `lib/screens/change_password_screen.dart`
- `lib/screens/my_reviews_screen.dart`
- `lib/screens/app_settings_screen.dart`
- `analysis_options.yaml`
- `test/widget_test.dart`

## Customer Booking UI

Completed:
- Added reusable booking status timeline widget.
- Added full timeline to customer booking detail.
- Added compact timeline/progress strip to customer booking cards.
- Cleaned broken rupee text in booking cards to `Rs`.
- Upgraded customer bookings screen toward global design consistency:
  - app shell uses `WorkableDesign`
  - added premium page header
  - converted filter chips away from old deep-purple styling
  - converted booking cards to shared status/info components
  - converted login, empty, and error states to shared empty-state component
  - made amount parsing safer for numeric or string booking amounts
- Booking form screen UI polish completed:
  - imported `WorkableDesign`
  - app shell, header, cards, form fields, selected address state, schedule note, and submit/loading button now use shared design tokens
  - removed active deep-purple visual styling from the booking form path
  - preserved worker validation, address selector, date/time picker, and booking submission logic
  - focused analyzer passed for `booking_form_screen.dart`
- Booking timeline stages:
  - Requested
  - Accepted
  - In Progress
  - Completion
  - Payment
  - Completed

Files:
- `lib/widgets/booking_status_timeline.dart`
- `lib/widgets/workable_ui.dart`
- `lib/screens/customer_booking_detail_screen.dart`
- `lib/screens/customer_bookings_screen.dart`

## Customer-Facing Worker Profile

Completed:
- Worker profile screen customer-facing polish completed:
  - imported and applied `WorkableDesign`
  - page shell, loading state, favorite action, profile headline, availability, stats, badges, action buttons, about card, service/pricing cards, services offered, portfolio cards, and review cards now use shared design tokens
  - preserved customer-facing conversion features: verification badge, availability, reviews, services, pricing, portfolio, booking action, chat action, favorite action
  - removed an old implementation comment from the UI file
  - focused analyzer passed for `worker_profile_screen.dart`

File:
- `lib/screens/worker_profile_screen.dart`

## Payment Trust Flow

Completed:
- Added `PaymentReconciliationService`.
- Added trust-based payment review states:
  - `customer_reported_paid`
  - `cash_pending_confirmation`
  - `payment_under_review`
  - `paid`
  - `rejected`
  - `payment_rejected`
- Customer payment flow supports cash option.
- Worker can confirm cash received.
- Admin can approve/reject reported UPI payments.
- Booking moves cleanly toward completed/paid after approval.
- Rejected payment returns booking to payment due / rejected payment state.
- Added admin payment review screen.
- Wired admin payment review route.
- Added admin dashboard shortcut for payment review.
- UPI launch is protected:
  - App only opens live UPI if booking has a real UPI ID such as `merchantUpiId`, `businessUpiId`, `workerUpiId`, or `upiId`.
  - If no real UPI ID exists, the app blocks fake live payment.

Files:
- `lib/services/payment_reconciliation_service.dart`
- `lib/screens/customer_payment_screen.dart`
- `lib/screens/worker_job_details_screen.dart`
- `lib/screens/admin/admin_payment_review_screen.dart`
- `lib/screens/admin/admin_verification_dashboard.dart`
- `lib/main.dart`

## Worker Payout Flow

Completed:
- Added `PayoutRequestService`.
- Worker can request payout from eligible completed/paid bookings.
- Eligible bookings are marked with payout request fields.
- Payout requests are written to `payoutRequests`.
- Admin payout review screen added.
- Admin can mark payout paid.
- Admin can reject payout.
- Worker can see payout request history/status.
- Admin payout route and shortcut wired.
- Fixed payout method detection:
  - Service now reads nested `payout` config.
  - Service also reads top-level `upiId`, `bankAccountNumber`, and `ifscCode` saved during worker signup.
- Worker payout methods screen upgraded:
  - uses `WorkableDesign`
  - validates UPI ID
  - validates bank account number
  - validates IFSC code
  - writes nested `payout` config
  - writes top-level `paymentMethod`, `upiId`, `bankAccountNumber`, and `ifscCode` compatibility fields
  - shows selected/default payout readiness

Files:
- `lib/services/payout_request_service.dart`
- `lib/screens/worker_earnings_screen.dart`
- `lib/screens/worker_payout_methods_screen.dart`
- `lib/screens/admin/admin_payout_review_screen.dart`
- `lib/screens/admin/admin_verification_dashboard.dart`
- `lib/main.dart`

## Worker Signup And Onboarding

Completed:
- Rebuilt worker signup as a premium onboarding flow.
- Added shared onboarding shell:
  - `lib/widgets/worker_onboarding_shell.dart`
- Worker account creation now collects:
  - profile photo
  - full name
  - age
  - gender
  - phone with OTP
  - email
  - password
- Worker is hidden by default during signup:
  - `profileVisibility: false`
  - `visibleToUsers: false`
  - `workerStatus: onboarding`
  - `visibilityBlockedReason: Complete onboarding and verification`
- Step 1 service area redesigned:
  - address
  - city
  - pincode
  - travel radius
  - map pin
  - current location action
- Step 2 skills redesigned:
  - clean categories
  - no corrupted emoji/rupee text
  - per-skill experience selection
- Added `skillExperience` field to `WorkerOnboardingData`.
- Step 3 pricing/payout redesigned:
  - rate per selected skill
  - UPI validation
  - bank account validation
  - IFSC validation
- Step 4 availability redesigned:
  - working days
  - start/end hours
  - flexible hours
  - urgent job availability
- Step 5 identity verification redesigned:
  - primary ID type
  - ID front upload
  - ID back upload
  - OCR support
  - selfie capture
  - face match
  - verification consent
- Replaced `Skip for Now` with `Finish without visibility`.
- If worker skips verification:
  - enters worker dashboard
  - remains hidden from customers
  - `verificationStatus: skipped`
  - `workerStatus: verification_pending`
- If worker submits verification:
  - remains hidden until admin review
  - `verificationStatus: submitted`
  - `workerStatus: verification_submitted`

Files:
- `lib/screens/worker_signup_screen.dart`
- `lib/screens/worker_signup/step1_profile_screen.dart`
- `lib/screens/worker_signup/step2_skills_screen.dart`
- `lib/screens/worker_signup/step3_pricing_screen.dart`
- `lib/screens/worker_signup/step4_schedule_screen.dart`
- `lib/screens/worker_signup/step5_verify_screen.dart`
- `lib/models/worker_onboarding_data.dart`
- `lib/widgets/worker_onboarding_shell.dart`

## Worker Visibility

Completed:
- Confirmed customer dashboard visibility gate uses `visibleToUsers`.
- Worker visibility sync exists in `WorkerVisibilityService`.
- Added reusable worker visibility/readiness panel.
- Worker dashboard shows live visibility status after welcome card.
- Worker account page uses the same live visibility panel.
- Panel shows:
  - visible / hidden / under review
  - profile readiness progress
  - onboarding complete
  - profile photo
  - service location
  - services and pricing
  - availability
  - payout method
  - selfie verification
  - blocked reason
  - buttons to verification and profile

Files:
- `lib/services/worker_visibility_service.dart`
- `lib/widgets/worker_visibility_status_panel.dart`
- `lib/screens/worker_dashboard_screen.dart`
- `lib/screens/account/worker_account_screen.dart`

## Worker Dashboard

Completed:
- Removed mock weekly performance data.
- Dashboard metrics now use real Firestore bookings.
- Today earnings come from completed bookings.
- Today completed/scheduled counts come from real bookings.
- Rating comes from worker profile data.
- Replaced dummy quick actions with real actions:
  - Active Jobs
  - Payouts
  - Edit Profile
  - Verification
- Dashboard now includes worker visibility/readiness panel.
- More dashboard UI moved toward `WorkableDesign`.

File:
- `lib/screens/worker_dashboard_screen.dart`

## Worker Earnings And Payout Dashboard

Completed:
- Rebuilt worker earnings screen with `WorkableDesign`.
- Shows:
  - total earned
  - available payout amount
  - pending money amount
  - paid out amount
  - earned jobs
  - payout request card
  - payout request history
  - recent earnings
- Payout request button is disabled unless:
  - completed/paid jobs are eligible
  - valid payout method exists
- Payout method warning links to payout methods screen.
- Recent earnings cards cleaned.
- Removed corrupted text separators from this screen.

Files:
- `lib/screens/worker_earnings_screen.dart`
- `lib/services/payout_request_service.dart`

## Worker Active Jobs

Completed:
- Upgraded worker active jobs screen into a real operations board.
- Uses `WorkableDesign` instead of one-off generic colors.
- Added top summary metrics:
  - active jobs
  - new requests
  - jobs needing action
- Split work into clear sections:
  - New Requests
  - Accepted
  - In Progress
  - Completion Requested
  - Payment Due / Review
- New request cards support accept and decline.
- Accepted jobs can be moved to in progress.
- In-progress jobs can request customer completion confirmation.
- Cash/payment-review jobs guide the worker to details for confirmation/review.
- Cards now show customer, schedule, address, amount, issue summary, status pill, next-step guidance, details, and chat.
- Fixed broken date/time separator text.
- Focused analyzer passed with no issues.

File:
- `lib/screens/worker_active_jobs_screen.dart`

## Worker Job History

Completed:
- Upgraded worker job history into a finished closed-job record screen.
- Uses `WorkableDesign` for consistent premium styling.
- Shows summary metrics:
  - completed-job earnings
  - completed job count
  - average customer rating from rated jobs
  - cancelled count
  - issue/rejected/dispute count
- Supports filters:
  - All
  - Completed
  - Cancelled
  - Rejected
  - Disputed
- History now recognizes completed/paid bookings through both `status` and `paymentStatus`.
- History now recognizes cancelled/declined, rejected/payment rejected, and disputed bookings.
- Cards show service, customer, schedule, address, payment method/status, issue summary, recorded earning/amount, customer rating, optional review text, and details action.
- Fixed broken date/time separator text.
- Focused analyzer passed with no issues.

File:
- `lib/screens/worker_job_history_screen.dart`

## Worker Professional Profile

Completed:
- Upgraded worker professional profile into a stronger business-control page.
- Added live `WorkerVisibilityStatusPanel` at the top so workers can see readiness/visibility directly while editing.
- Page now loads service aliases from `skills` or `services`.
- Page now loads pricing from numeric `pricing` or existing `wageMap`.
- Page now loads skill experience from `skillExperience`.
- Save now writes marketplace-compatible service fields:
  - `skills`
  - `services`
  - `serviceCategories`
  - numeric `pricing`
  - `displayPricing`
  - `wageMap`
  - `skillExperience`
- Save now writes both `serviceRadius` and `serviceRadiusKm`.
- Save now writes schedule using both `workingDays` and `availableDays`.
- Save marks `isOnboardingComplete: true` after required profile fields are valid.
- Added service/pricing preview so workers can see what customers will see.
- Added validation for at least one service and a valid starting price.
- Moved more UI styling to `WorkableDesign`.
- Fixed visibility panel availability compatibility so it recognizes both `availableDays` and older `workingDays`.
- Focused analyzer passed with no issues.

Files:
- `lib/screens/worker_professional_profile_screen.dart`
- `lib/widgets/worker_visibility_status_panel.dart`

## Worker Portfolio

Completed:
- Upgraded worker portfolio into a stronger trust-building showcase page.
- Kept existing compatible Firestore path:
  - `workers/{uid}/portfolio`
- Kept Firebase Storage upload/delete behavior.
- Added service/category field for each work sample.
- Added sample type selector:
  - Completed work
  - Before
  - After
- Portfolio items now save:
  - `imageUrl`
  - `storagePath`
  - `title`
  - `category`
  - `serviceCategory`
  - `sampleType`
  - `description`
  - `isVisible`
  - timestamps
- Worker document now syncs portfolio summary:
  - `portfolioCount`
  - `portfolioCategories`
  - `portfolioUpdatedAt`
- Added trust-focused header showing how many samples are visible.
- Added better loading, error, and empty states.
- Redesigned cards with `WorkableDesign`.
- Focused analyzer passed with no issues.

File:
- `lib/screens/worker_portfolio_screen.dart`

## Customer Payment And Booking Detail Polish

Completed:
- Upgraded customer checkout trust messaging.
- Customer payment screen now shows a clear payment-state card for:
  - payment due
  - payment started
  - UPI payment under review
  - cash pending worker confirmation
  - payment rejected
  - paid/completed
- Checkout actions are locked when payment is already under review, cash confirmation is pending, or booking is paid.
- Rejected payments now clearly explain that the customer can try payment again or choose cash.
- The missing real UPI ID message is now customer-safe:
  - tells the customer online UPI is not available for that booking
  - suggests cash or support instead of exposing internal merchant setup language
- Payment screen now uses more `WorkableDesign` styling.
- Customer booking detail now shows a payment status card using the same real payment states.
- Booking detail lets the customer continue/retry payment from due or rejected states.
- Booking detail now treats `paymentStatus: paid` as completed for review/payment display logic.
- Focused analyzer passed with no issues.

Files:
- `lib/screens/customer_payment_screen.dart`
- `lib/screens/customer_booking_detail_screen.dart`

## Duplicate / Legacy Screen Cleanup

Completed:
- Audited duplicate and weak screens against actual routes/navigation.
- Kept the stronger active screens:
  - `CustomerBookingsScreen` for customer booking history/all bookings.
  - `CustomerBookingReviewScreen` for customer reviews.
  - `WorkerEarningsScreen` for worker earnings/payout dashboard.
  - `WorkerPayoutMethodsScreen` for payout setup instead of old withdrawal.
  - `AppSettingsScreen` for shared customer/worker app settings.
- Redirected old route compatibility paths:
  - `/booking-history` -> `CustomerBookingsScreen(initialTab: 2)`
  - `/customer/booking-history` -> `CustomerBookingsScreen(initialTab: 2)`
  - `/view-earnings` -> `WorkerEarningsScreen`
  - `/withdraw` -> `WorkerPayoutMethodsScreen`
  - `/settings` -> `AppSettingsScreen`
  - `/worker-settings` -> `AppSettingsScreen`
- Worker dashboard earnings tab now opens `WorkerEarningsScreen` instead of old `ViewEarningsScreen`.
- Removed unused/dead files:
  - `lib/screens/custbkng.dart`
  - `lib/screens/order_history_screen.dart`
  - `lib/screens/firebase_storage_test_screen.dart`
  - `lib/screens/aadhar_card_verification_screen.dart`
  - `lib/screens/passport_verification_screen.dart`
  - `lib/screens/driving_license_verification_screen.dart`
  - `lib/screens/voter_id_verification_screen.dart`
  - `lib/screens/booking_history_screen.dart`
  - `lib/screens/view_earnings_screen.dart`
  - `lib/screens/withdrawal_screen.dart`
  - `lib/screens/settings_screen.dart`
  - `lib/screens/worker_settings_screen.dart`
- Cleaned the active customer review screen:
  - saves worker `averageRating`, `rating`, `reviewCount`, and `totalReviews`
  - removed analyzer warning from unused average calculation
  - replaced production `print`
  - fixed async context warnings
- Focused analyzer passed with no issues.
- Route/legacy cleanup batch completed:
  - fixed `/customer/repeat-booking` so it opens `RepeatBookingScreen` instead of `BookingFormScreen`
  - `booking_detail_screen.dart` is now a compatibility wrapper around `CustomerBookingDetailScreen`
    - removes fake cancel/reschedule snackbar behavior from the old booking detail page
    - keeps `/booking-detail` route working for old callers
  - `edit_profile_screen.dart` is now a role-aware compatibility wrapper:
    - workers go to `WorkerProfessionalProfileScreen`
    - customers go to `PersonalInformationScreen`
    - removes the old duplicate profile-edit form
  - `search_screen.dart` rebuilt:
    - uses shared `WorkableDesign`, `WorkablePageHeader`, `WorkableSectionCard`, and `WorkableInfoRow`
    - searches visible workers safely
    - supports worker data from `services`, `skills`, and `serviceCategories`
    - avoids crashes when service fields are missing or stored as strings/maps/lists
    - preserves navigation to `WorkerListScreen`
    - includes honest note that Smart Demand Discovery will later handle missing services/categories
  - Focused analyzer passed for `main.dart`, `booking_detail_screen.dart`, `edit_profile_screen.dart`, and `search_screen.dart`.
- Customer ongoing/reschedule/confirmation cleanup completed:
  - `ongoing_services_screen.dart` rebuilt:
    - removed production debug prints and placeholder progress values
    - now shows active customer bookings with status-based progress
    - uses shared `WorkableDesign`, `WorkablePageHeader`, `WorkableSectionCard`, `WorkableStatusPill`, `WorkableInfoRow`, and `WorkableEmptyState`
    - supports filters for All, Today, and Action
    - opens `CustomerBookingDetailScreen` for real booking details
  - `customer_booking_confirmation_screen.dart` rebuilt:
    - uses shared UI and clear post-booking trust copy
    - adds actions for View My Bookings and Back to Dashboard
  - `customer_reschedule_screen.dart` rebuilt:
    - preserves Firestore reschedule update flow
    - writes `status: reschedule_requested`, `rescheduleRequestedAt`, and `updatedAt`
    - uses shared UI, date/time pickers, loading state, and confirmation state
    - removes deep-purple/gradient styling and async context risk
  - Individual focused analyzer passed for all three screens.
  - Combined analyzer command timed out once, but each screen analyzed cleanly by itself.
- Weak-route consolidation batch completed:
  - `add_skills_screen.dart` is now a compatibility wrapper around `WorkerProfessionalProfileScreen`
    - removes the old local-only skills list that did not save to Firestore
    - keeps `/add-skills` route working
  - `subscription_screen.dart` rebuilt as an honest planned-membership screen
    - removes fake subscription activation
    - cleans corrupted rupee text
    - explains that paid plans require production pricing, payment, tax, refund, and trust rules before launch
  - `location_permission_screen.dart` rebuilt:
    - uses shared `WorkableDesign` and shared UI components
    - uses real Geolocator permission checks
    - persists granted/denied state through `AppPreferencesService.setLocationServices`
    - returns `true`/`false` to caller instead of blindly routing to `/`
  - `become_worker_screen.dart` rebuilt as a real customer-to-worker conversion page
    - removes fake demo active-worker toggle and hardcoded worker stats
    - explains worker signup requirements, benefits, and approval/visibility flow
    - routes to `WorkerSignupScreen`
  - Focused analyzer passed for all four screens.
- Final pre-architecture audit/admin polish completed:
  - `profile_tab_screen.dart` is now a compatibility wrapper around `AccountScreenFactory`
    - removes dependency on old `tabs/home_tab.dart`, `tabs/personal_info_tab.dart`, `tabs/security_tab.dart`, and `tabs/privacy_data_tab.dart`
    - old tab files are no longer imported by this legacy profile entry point
  - `admin_verification_dashboard.dart` rebuilt:
    - uses shared `WorkableDesign`, `WorkablePageHeader`, `WorkableSectionCard`, `WorkableStatusPill`, `WorkableInfoRow`, and `WorkableEmptyState`
    - preserves Firestore `adminVerificationQueue` loading
    - preserves navigation to verification review, payment review, and payout review
    - improves pending queue cards with contact/document/submission context
  - `verification_review_screen.dart` targeted polish:
    - moved shell to `WorkableDesign.canvas`
    - user-not-found state now uses shared empty state
    - replaced active deprecated opacity calls with `withValues`
    - removed analyzer spread-list lints in active UI
  - Focused analyzer passed for `profile_tab_screen.dart`, `admin_verification_dashboard.dart`, and `verification_review_screen.dart`.
  - Final targeted scan found no old `Colors.deepPurple`, dummy/fake/placeholder text, or debug `print` markers in the recently cleaned route/legacy/customer/admin screens.

Architecture readiness:
- Cleanup gate is complete enough to start the Clean Architecture + Riverpod pilot.
- Known residual cleanup outside the pilot:
  - old `tabs/*` files are orphaned and can be deleted in a future dead-file cleanup
  - some broader full-project analyzer warnings remain in non-screen/core/service files
  - admin verification review screen is functionally polished but can receive a deeper full redesign later

Files:
- `lib/main.dart`
- `lib/screens/worker_dashboard_screen.dart`
- `lib/screens/customer_booking_review_screen.dart`

## Generic Help Request Backbone

Completed:
- Added first real backbone for the broader "helping hand" product direction.
- Added Firestore service for generic help requests:
  - `HelpRequestService`
  - writes to `helpRequests`
  - stores customer profile info
  - stores request type, title, description, pickup address, destination, urgency, preferred date/time, budget, location, status, and timeline
- Added customer create screen:
  - `GenericHelpRequestScreen`
  - route: `/customer/help-request`
- Supported request types:
  - General help
  - Pickup
  - Drop
  - Delivery
  - Urgent help
  - Elder support
- Supported urgency:
  - Normal
  - Today
  - Urgent
- Initial status flow stored in timeline:
  - open
  - accepted
  - in_progress
  - completion_requested
  - payment_due
  - completed
  - cancelled
- Customer can choose a saved address from `AddressManagementScreen`.
- Customer dashboard now has a visible `Request help` floating action button.
- Focused analyzer passed with no issues.

Files:
- `lib/services/help_request_service.dart`
- `lib/screens/generic_help_request_screen.dart`
- `lib/screens/customer_dashboard_screen.dart`
- `lib/main.dart`

## Help Request Feature Architecture

Completed:
- Migrated Generic Help Request into feature-first architecture.
- Added domain model:
  - `lib/features/help_requests/domain/help_request_draft.dart`
- Added repository:
  - `lib/features/help_requests/data/help_request_repository.dart`
- Added Riverpod provider:
  - `lib/features/help_requests/presentation/help_request_providers.dart`
- Added feature screen:
  - `lib/features/help_requests/presentation/generic_help_request_screen.dart`
- Kept compatibility:
  - `lib/screens/generic_help_request_screen.dart` now exports the feature screen
  - `lib/services/help_request_service.dart` now delegates to `HelpRequestRepository`
  - existing `/customer/help-request` route remains stable
- Preserved Firestore shape:
  - writes to `helpRequests`
  - stores customer profile info
  - stores request type, title, description, pickup/destination, urgency, preferred date/time, budget, selected address/location, status, payment status, and timeline
- Added `source` field for future AI-created requests.
- This gives AI Smart Booking a clean repository path to create generic help requests later without depending on UI controllers.
- Focused analyzer passed for help request feature files, wrappers, route users, and notification navigation.

## Worker Help Requests Flow

Completed:
- Added worker-side open Help Requests flow as part of the existing Help Request feature module:
  - `lib/features/help_requests/domain/help_request.dart`
  - `lib/features/help_requests/presentation/worker_help_requests_screen.dart`
- Extended `HelpRequestRepository` with:
  - `watchOpenHelpRequests`
  - `watchWorkerHelpRequests`
  - `acceptHelpRequest`
- Worker accept flow now uses a Firestore transaction:
  - only accepts requests still in `open` status
  - writes `status: accepted`
  - stores `workerId`, `acceptedWorkerId`, worker name, optional worker phone, accepted timestamp, updated timestamp, and `timeline.accepted`
  - updates worker `activeHelpRequestIds`
- Customer gets a real notification document when a worker accepts a help request.
  - Existing Cloud Function push trigger can deliver this as push after notification document creation.
- Added route:
  - `/worker/help-requests`
- Added worker entry points:
  - Worker dashboard quick action
  - Worker account Work section
- Notification tap routing now opens Worker Help Requests for worker/new-help-request payloads.
- Customer accepted-help notification currently routes to notification inbox until a customer help-request detail screen exists.
- Focused analyzer passed for the new help request flow, route integrations, worker dashboard/account, and notification navigation.

Recommended next help-request step:
- Add customer and worker help-request detail screens with start work, completion requested, payment due, cash/UPI payment flow, and completion history.

## Booking Creation Architecture

Completed:
- Added first feature-first Booking Creation module:
  - `lib/features/bookings/domain/booking_draft.dart`
  - `lib/features/bookings/data/booking_repository.dart`
  - `lib/features/bookings/presentation/booking_providers.dart`
- Moved booking creation logic out of `BookingFormScreen` into `BookingRepository.createBooking`.
- Preserved existing customer booking behavior:
  - customer profile lookup
  - optional preselected worker
  - worker visibility/eligibility gate
  - worker schedule validation
  - worker service-radius validation
  - service name and price extraction from worker profile
  - selected address metadata
  - `pending` status when worker is selected
  - `pending_assignment` status when no worker is selected
  - payment defaults to Cash and `paymentStatus: not_started`
- `BookingDraft` is now the reusable input model for manual booking, repeat booking, future Smart Demand booking, and AI Smart Booking.
- `BookingFormScreen` now collects form input and calls the repository instead of writing directly to Firestore.
- Added `source` field to booking creation so future AI-created/manual/repeat bookings can be tracked.
- Focused analyzer passed for the booking feature files and booking form integration.

Recommended next booking architecture step:
- Add booking status/action repository for accept, start work, request completion, payment due, and completion transitions so worker/customer detail screens stop writing Firestore status fields directly.

## Booking Status Action Architecture

Completed:
- Added centralized booking lifecycle action repository:
  - `lib/features/bookings/data/booking_action_repository.dart`
- Added Riverpod provider:
  - `bookingActionRepositoryProvider`
- Repository now owns core booking transitions:
  - accept booking -> `confirmed`
  - decline booking -> `cancelled`
  - start work -> `in_progress`
  - request completion -> `completion_requested`
  - customer confirms completion -> `payment_due`
  - customer disputes completion -> `completion_disputed`
  - customer cancels booking -> `cancelled`
- Each action writes consistent timestamps, `updatedAt`, and timeline fields.
- Wired existing screens into the repository:
  - `worker_active_jobs_screen.dart`
  - `worker_job_details_screen.dart`
  - `customer_booking_detail_screen.dart`
- Preserved existing behavior:
  - worker verification gate before accepting from job detail
  - cash confirmation still uses `PaymentReconciliationService`
  - customer completion confirmation still routes to payment screen
  - customer dispute flow still captures reason
- Focused analyzer passed for the repository, provider, and wired booking screens.

Recommended next booking step:
- Move payment-specific transitions from `customer_payment_screen.dart` and `PaymentReconciliationService` into a shared payment/booking payment action layer, then reuse it for Help Request payment flow.

## Booking Payment Action Architecture

Completed:
- Added centralized booking payment repository:
  - `lib/features/bookings/data/booking_payment_repository.dart`
- Added payment breakdown model:
  - `BookingPaymentBreakdown`
- Added Riverpod provider:
  - `bookingPaymentRepositoryProvider`
- Centralized payment transitions:
  - cash payment reported by customer -> `cash_pending_confirmation` and `payment_under_review`
  - UPI payment initiated -> `initiated` and `payment_initiated`
  - UPI launch failed -> `launch_failed` and `payment_initiated`
  - customer reported UPI paid -> `customer_reported_paid` and `payment_under_review`
  - worker/admin approves payment -> `paid` and booking `completed`
  - admin rejects payment -> `payment_rejected` and booking returns to `payment_due`
- `CustomerPaymentScreen` now handles UI, UPI launching, and follow-up prompts, while `BookingPaymentRepository` owns Firestore booking/transaction updates.
- `PaymentReconciliationService` is now a compatibility wrapper around `BookingPaymentRepository`, so existing worker/admin imports continue to work.
- Preserved existing admin payment review and worker cash confirmation behavior.
- Focused analyzer passed for payment repository, provider, compatibility service, customer payment screen, worker job detail, and admin payment review.

Recommended next payment step:
- Reuse `BookingPaymentRepository` from Help Request detail/payment flow after customer and worker Help Request detail screens are built.

## Help Request Detail Flow

Completed:
- Added customer and worker Help Request detail screens:
  - `lib/features/help_requests/presentation/customer_help_request_detail_screen.dart`
  - `lib/features/help_requests/presentation/worker_help_request_detail_screen.dart`
- Added single-request live stream:
  - `HelpRequestRepository.watchHelpRequest`
  - `helpRequestProvider`
- Extended `HelpRequest` model with worker name and worker phone accessors.
- Added Help Request lifecycle actions:
  - worker start help request -> `in_progress`
  - worker request completion -> `completion_requested`
  - customer confirms completion -> `payment_due`
  - customer cancels request -> `cancelled`
  - customer marks cash payment -> `cash_pending_confirmation`
  - worker confirms cash received -> `completed` and `paid`
- Added routes:
  - `/customer/help-request-detail`
  - `/worker/help-request-detail`
- Customer help request creation now opens the new customer detail page after creation.
- Worker Help Requests list now has detail navigation for open and accepted requests.
- Notification tap routing now opens help request detail screens when payload contains `helpRequestId` or `requestId`.
- Focused analyzer passed for help request model, repository, providers, create/list/detail screens, main routes, and notification navigation.

Important current limitation:
- Help Request detail supports cash completion now.
- UPI/payment gateway style Help Request payments are still planned; reuse `BookingPaymentRepository` pattern in the next pass.

Recommended next help-request step:
- Add UPI payment support for Help Requests or convert accepted Help Requests into normal booking/payment records when a worker accepts, whichever gives the cleaner long-term marketplace ledger.

## Customer Help Requests List

Completed:
- Added customer "My Help Requests" page:
  - `lib/features/help_requests/presentation/customer_help_requests_screen.dart`
- Added customer-owned stream:
  - `HelpRequestRepository.watchCustomerHelpRequests`
  - `customerHelpRequestsProvider`
- Page supports:
  - Active filter
  - All filter
  - History filter
  - live status/payment pills
  - worker assignment display
  - empty state with create action
  - pull to refresh
  - navigation to customer Help Request detail
- Added route:
  - `/customer/help-requests`
- Added customer entry points:
  - Customer dashboard floating action stack now has `My help` and `Request help`
  - Customer account quick action now opens Help Requests
  - Customer account Bookings & Services section now includes My Help Requests
- Focused analyzer passed for the customer help request list, repository/provider additions, main route, customer account, and customer dashboard.

Recommended next help-request step:
- Add UPI payment support for Help Requests or convert accepted Help Requests into normal booking/payment records when a worker accepts, whichever gives the cleaner long-term marketplace ledger.

## Help Request To Booking Conversion

Completed:
- Chose the cleaner long-term architecture:
  - `helpRequests` stays as the customer intake/demand record
  - `bookings` becomes the execution, completion, payment, review, payout, dispute, and ledger record
- Worker accepting a help request now creates a linked booking in the same Firestore transaction.
- Help request now stores:
  - `convertedToBooking: true`
  - `linkedBookingId`
  - `linkedBookingCreatedAt`
- Linked booking now stores:
  - `source: help_request`
  - `sourceHelpRequestId`
  - `requestKind`
  - customer details
  - worker details
  - service/request type
  - issue/description
  - pickup/destination details
  - budget/estimated price
  - normal booking status/payment fields
- Customer and worker help request detail screens now hand off to the normal booking/job detail screens when a linked booking exists.
- This means linked help requests reuse:
  - booking status action repository
  - customer completion confirmation
  - customer payment screen
  - UPI launch/payment reporting
  - cash confirmation
  - admin payment review
  - worker job detail actions
- Booking action updates now sync linked help request status so the customer help list stays meaningful.
- Booking payment updates now sync linked help request payment/completed/rejected state.
- Existing older help requests without `linkedBookingId` still keep their fallback help-request-only cash flow.
- Focused analyzer passed for help request model/repository/detail screens, booking action repository, booking payment repository, customer payment screen, and worker job detail.

Recommended next step:
- Add notifications for linked help-request booking milestones:
  - worker started work
  - completion requested
  - customer confirmed completion
  - customer reported payment/cash
  - payment approved/rejected

## Linked Help Request Milestone Notifications

Completed:
- Added real notification document creation for linked Help Request booking milestones.
- Booking status actions now notify:
  - customer when worker starts work
  - customer when worker requests completion confirmation
  - worker when customer confirms completion/payment due
  - worker when customer disputes completion
- Booking payment actions now notify:
  - worker when customer selects cash
  - worker when customer reports UPI paid
  - customer and worker when payment is approved/completed
  - customer when payment is rejected
- Notification documents include top-level routing fields:
  - `helpRequestId`
  - `bookingId`
  - `userRole`
  - `type`
  - `status`
  - `category: help_request`
  - `notificationCategory: help_request`
- This works with the existing `sendPushOnNotificationCreate` Cloud Function because it triggers from notification document creation.
- Focused analyzer passed for booking action repository, booking payment repository, notification routing, customer payment, worker job detail, and customer booking detail.

Recommended next step:
- Add worker-side Help Request history/earnings visibility, because linked help requests now flow through normal bookings but workers still need a clear history surface for help jobs.

## Worker Help Job History And Earnings Visibility

Completed:
- Worker Job History now clearly identifies linked Help Request bookings.
- Added `Help` filter in worker job history.
- Job history summary now shows help job count and completed help earnings.
- Help-origin jobs show a `help request` badge in history cards.
- Worker Earnings now includes a dedicated Help Request earnings card:
  - completed help job count
  - pending help payment count
  - total help earnings
- Recent earnings now labels help-origin jobs as `Help: <service>`.
- Existing payout logic already includes linked help bookings because they are normal paid/completed booking records.
- Focused analyzer passed for worker job history, worker earnings, and payout request service.

Recommended next step:
- Add a small admin/help marketplace review surface or start the first AI Smart Booking Assistant foundation, because the normal booking, help request, matching, payment, notification, and worker visibility foundations are now connected.

## AI Smart Booking Foundation Phase 1

Completed:
- Added the first Smart Booking feature-first module:
  - `lib/features/smart_booking/domain/smart_booking_assessment.dart`
  - `lib/features/smart_booking/data/smart_booking_assistant_repository.dart`
  - `lib/features/smart_booking/presentation/smart_booking_providers.dart`
  - `lib/features/smart_booking/presentation/smart_booking_assistant_screen.dart`
- Added route:
  - `/customer/smart-booking`
- Added customer entry points:
  - Customer dashboard floating action stack now includes Smart book.
  - Customer account Bookings & Services section now includes Smart Booking.
- Current behavior:
  - customer types a natural need such as water leak, AC not cooling, pickup medicine, elder support, or urgent help
  - assistant reuses Smart Demand Discovery to guess category and find matched workers
  - assistant detects basic urgency locally
  - assistant recommends either worker booking or a generic help request
  - assistant shows suggested follow-up questions
  - customer can open matched workers or create a help request
- This is intentionally a free local-rule foundation, not a paid AI API integration yet.
- Focused analyzer passed for the Smart Booking module, route, dashboard/account entry points, Smart Demand repository, and Worker List screen.

Important current limitations:
- No real LLM/API is connected yet.
- No voice/photo diagnosis yet.
- Help Request prefill from the Smart Booking assessment is still planned.
- No AI quota/cost-control backend is active yet.

Recommended next Smart Booking steps:
1. Completed: Pass Smart Booking assessment data into Generic Help Request as prefilled draft fields.
2. Add lightweight AI quota/cost tracking before connecting a real AI provider.
3. Add optional real AI Service Diagnosis only for unclear/low-confidence cases, photo/voice cases, or unknown categories.

## Smart Booking To Help Request Prefill

Completed:
- Added `HelpRequestPrefill` as a typed bridge from Smart Booking to Generic Help Request.
- Smart Booking now passes:
  - original customer query
  - guessed category
  - urgency
  - demand signal id when available
  - city when available
- Generic Help Request now applies the prefill once when opened:
  - request type
  - title
  - description
  - urgency
- Help Request creation now stores:
  - `source: smart_booking`
  - `sourceMetadata` with query/category/urgency/demand/city context
- Manual Help Request creation still works unchanged with `source: customer_manual`.
- Focused analyzer passed for Smart Booking, Help Request prefill, Help Request draft/repository, Generic Help Request screen, and main route wiring.

Recommended next Smart Booking step:
- Add AI quota/cost-control foundation before any real AI API:
  - daily Smart Helps allowance
  - local-rule first behavior
  - Firestore usage tracking
  - reserve paid AI calls for unclear, photo/voice, or unknown-category cases.

## Smart Help Quota And AI Cost-Control Foundation

Completed:
- Added a Smart Help quota foundation before connecting any real AI API:
  - `lib/features/smart_booking/domain/smart_help_quota.dart`
  - `lib/features/smart_booking/data/smart_help_quota_repository.dart`
- Added Riverpod providers for quota repository and today's quota stream.
- Smart Booking screen now shows a customer-friendly Smart Helps card:
  - remaining Smart Helps for today
  - free local checks completed today
  - AI allowance used today
- Local Smart Booking assessment remains free and unlimited from a cost perspective.
- Every local Smart Booking assessment now records lightweight usage in:
  - `aiUsage/{uid}/days/{yyyy-MM-dd}`
- Stored usage avoids saving the full customer query; it records query length, category, urgency, recommended path, worker-match result, and counters.
- Added `reserveAiHelp` foundation for future paid AI calls:
  - checks daily allowance
  - increments `aiCallsUsed`
  - tracks estimated tokens
  - records blocked attempts when quota is exhausted
- Focused analyzer passed for Smart Booking quota, providers, assistant screen, Smart Booking assessment/repository, Help Request prefill, Generic Help Request screen, and main route wiring.

Important current limitations:
- No real AI provider/API is connected yet.
- Quota enforcement is client-side foundation for now; before production paid AI, move final enforcement into Cloud Functions or another trusted backend.
- The current daily allowance is 3 Smart Helps per user per day.

Recommended next Smart Booking step:
- Add a real AI decision gate:
  - use local rules first
  - call AI only when confidence is low, category is unknown, photo/voice is used, or customer explicitly asks for deeper diagnosis
  - if quota is exhausted, keep manual/local Smart Booking available instead of blocking the customer.

## Backend AI Quota Enforcement Gate

Completed:
- Added secure callable Cloud Function:
  - `runSmartBookingAiDiagnosis`
- Function behavior:
  - requires Firebase Auth
  - validates prompt length
  - checks OpenAI API key configuration before reserving quota
  - if no AI key is configured, returns a safe backend local fallback and does not consume quota
  - when an AI key is configured, reserves quota in a Firestore transaction before the AI call
  - blocks with `resource-exhausted` when daily Smart Helps are finished
  - writes usage to `aiUsage/{uid}/days/{yyyy-MM-dd}`
  - records `aiCallsUsed`, estimated tokens, blocked calls, reason, and timestamps
- Added backend fallback category/urgency diagnosis for setup/testing.
- Verification passed:
  - `node --check index.js`
  - `npm run lint`

Important current limitations:
- Real AI provider call is not connected yet; the function currently returns backend fallback diagnosis.
- Before production, Firestore rules should allow users to read their own usage but not manually increase quota.

Next activation steps:
1. Deploy Functions:
   - `firebase deploy --only functions`
2. Later, configure AI provider key:
   - Firebase Functions config or Secret Manager
3. Completed: Add Flutter `cloud_functions` dependency and call this backend from Smart Booking.

## Flutter Smart Booking Backend Diagnosis Client

Completed:
- Added `cloud_functions` dependency to the Flutter app.
- Added Smart Booking backend diagnosis model:
  - `lib/features/smart_booking/domain/smart_booking_ai_diagnosis.dart`
- Smart Booking repository now calls:
  - `runSmartBookingAiDiagnosis`
  - region: `us-central1`
- Smart Booking screen now includes a controlled `Deeper Diagnosis` action.
- Normal local Smart Booking remains the default fast/free path.
- Deeper Diagnosis displays:
  - backend category
  - urgency
  - summary
  - next questions
  - whether real AI was used or backend fallback was used
  - remaining Smart Helps when quota is reserved
- Because no real AI API key/provider is configured yet, the deployed backend returns safe fallback diagnosis and does not consume quota.
- Focused analyzer passed for Smart Booking backend diagnosis model/repository/screen, quota files, Help Request prefill, Generic Help Request screen, and main route wiring.

Recommended next Smart Booking steps:
1. Completed: Add Firestore rules for `aiUsage`.
2. Completed: Decide AI provider and model.
3. Configure backend AI key securely.
4. Completed: Replace backend fallback with real provider call and structured response parsing.

## Real AI Provider Wiring For Smart Booking

Completed:
- Wired `runSmartBookingAiDiagnosis` to OpenAI's Responses API.
- Default backend model:
  - `gpt-5.6-luna`
- Model can be changed without code edits through:
  - `openai.model`
- API key is read only on the backend through:
  - `openai.key`
- The Flutter app never receives or stores the AI API key.
- Added strict structured JSON schema for Smart Booking diagnosis:
  - category
  - urgency
  - confidence
  - summary
  - questions
  - recommended path
  - price range
  - safety note
- Added privacy/cost safeguards:
  - `store: false`
  - maximum output token limit
  - quota is reserved before real AI call
  - usage records actual token totals when the provider returns usage
  - provider failure returns safe backend fallback instead of breaking the customer flow
- Verification passed:
  - `node --check index.js`
  - `npm run lint`

Activation steps:
1. Configure backend key:
   - `firebase functions:config:set openai.key="YOUR_OPENAI_API_KEY" openai.model="gpt-5.6-luna"`
2. Deploy Functions:
   - `firebase deploy --only functions`
3. Test from Smart Booking:
   - run local Smart Booking
   - tap `Deeper Diagnosis`
   - confirm the result shows `AI used`

## AI Result To Help Request Flow Polish

Completed:
- Smart Booking AI diagnosis model now keeps:
  - price range
  - safety note
  - recommended path
  - AI/provider/quota metadata
- Smart Booking result panel now displays:
  - backend category and urgency
  - estimated price range when available
  - safety note when available
- Help Request prefill now prefers AI category and urgency when a Deeper Diagnosis exists.
- Help Request description now includes AI summary, estimated range, and safety note when available.
- Help Request `sourceMetadata` now stores `aiDiagnosis` when the request was created after Deeper Diagnosis.
- Testing Backlog updated with AI-to-help-request checks.
- Focused analyzer passed for AI diagnosis model, Help Request prefill, Smart Booking screen, Generic Help Request screen, Help Request draft, and Help Request repository.

Recommended next Smart Booking step:
- Add a lightweight AI result cache for common repeated requests so frequent prompts like AC not cooling or water leaking can avoid repeated AI calls when a recent high-confidence diagnosis already exists.

## Smart Booking AI Diagnosis Cache

Completed:
- Added backend cache for repeated Smart Booking AI diagnosis requests:
  - collection: `smartBookingAiCache`
  - cache key: normalized customer request text
  - TTL:
    - urgent diagnoses: 6 hours
    - high-confidence diagnoses: 72 hours
    - medium-confidence diagnoses: 24 hours
    - low-confidence diagnoses are not cached
- Cache check runs before quota reservation.
- Cached diagnosis returns without consuming another Smart Help.
- Cache hits update:
  - `smartBookingAiCache/{cacheKey}.hitCount`
  - `aiUsage/{uid}/days/{yyyy-MM-dd}.cachedAiHits`
- Successful provider results are cached when eligible.
- Flutter AI diagnosis model now tracks:
  - `cached`
  - `cacheKey`
- Smart Booking UI now shows:
  - `Cached AI`
  - `No quota used`
- Firestore rules now protect `smartBookingAiCache` from client writes.

Recommended next step:
- Deploy Functions and Firestore rules, then later test cache behavior during the testing phase.

## AI Recommended Action Polish

Completed:
- Smart Booking now uses AI `recommendedPath` to prioritize customer actions.
- If AI recommends `worker_booking`:
  - `View Workers` becomes the primary action.
  - `Create Help Request` remains available as a secondary action.
- If AI recommends `help_request`:
  - `Create Help Request` becomes the primary action.
  - `View Workers` remains available when matches exist.
- If AI recommends `emergency`:
  - safety-first status and guidance card are shown.
  - primary action becomes `Request Urgent Help`.
  - customer must confirm a safety warning before opening Help Request.
- Testing Backlog updated with recommended-action checks.

Recommended next step:
- Add AI confidence and recommended path labels to the Smart Booking result panel, or move next to the broader architecture/security plan depending on quota.

## AI Confidence And Path Labels

Completed:
- Smart Booking AI diagnosis model now stores `confidence`.
- AI diagnosis metadata saved into Help Request now includes confidence.
- Smart Booking AI panel now shows customer-friendly confidence labels:
  - High confidence
  - Medium confidence
  - Needs details
- Smart Booking AI panel now shows customer-friendly recommended path labels:
  - Best: compare workers
  - Best: help request
  - Best: urgent help
- Testing Backlog updated with confidence/path label checks.

Recommended next step:
- Move next to broader production readiness planning, or add the next Smart Booking improvement only if it is small and clearly useful.

## Firestore Smart Help Usage Rules

Completed:
- Added local Firestore rules file:
  - `firestore.rules`
- Wired Firestore rules into:
  - `firebase.json`
- Added protected `aiUsage` rules:
  - signed-in users can read only their own usage
  - admins can read usage
  - client apps cannot create, update, or delete `aiUsage`
  - Cloud Functions/Admin SDK can still write usage because Admin SDK bypasses Firestore client rules
- Kept a development-compatible authenticated fallback for existing collections:
  - `allow read, write: if signedIn()`
- Verified `firebase.json` parses correctly.

Important current limitation:
- These are not final production rules for the whole marketplace.
- The `aiUsage` protection is strong, but the rest of the app still needs a collection-by-collection production rules pass for bookings, workers, users, payments, payouts, reviews, messages, admin queues, and demand signals.

Deploy command:
- `firebase deploy --only firestore:rules`

## Worker Matching Module

Completed:
- Added reusable feature-first Worker Matching module:
  - `lib/features/worker_matching/domain/worker_match_query.dart`
  - `lib/features/worker_matching/domain/worker_match_result.dart`
  - `lib/features/worker_matching/data/worker_matching_repository.dart`
  - `lib/features/worker_matching/presentation/worker_matching_providers.dart`
- Added `WorkerMatchQuery` as the shared input model for search text, guessed category, urgency, customer location, and result limit.
- Added `WorkerMatchResult` as the shared output model with worker id, worker data, match score, and customer-readable match reasons.
- Matching now scores workers using:
  - direct text/skill fit
  - category fit
  - service fit
  - availability
  - verification
  - rating
  - completed job count
  - pricing availability
  - urgency boost for available/verified workers
- Smart Demand Discovery now uses `WorkerMatchingRepository` instead of owning worker ranking inside the demand repository.
- This module is now reusable for:
  - customer dashboard search
  - Smart Demand Discovery
  - Generic Help Request worker suggestions
  - Booking creation
  - Emergency Mode
  - future AI Service Diagnosis and Smart Booking Assistant
- Focused analyzer passed for Worker Matching and Smart Demand touched files.

Recommended next architecture step:
- Build worker-side open Help Requests list and accept flow, or rearchitecture Booking Creation enough that AI Smart Booking can call it cleanly.

## Worker Account

Completed:
- Worker account page already had many connected pages.
- Replaced older visibility card with reusable `WorkerVisibilityStatusPanel`.
- Clarified `BaseAccountScreen` role:
  - it is not a visible route/page by itself
  - it is an abstract shared parent used by customer and worker account screens
  - it centralizes user profile listening, common account state, reusable profile card, menu row, and logout behavior
- Started account design-system migration:
  - `BaseAccountScreen` profile card and menu rows now use `WorkableDesign`
  - worker account shell/profile/stat/section/logout styling now uses `WorkableDesign`
  - fixed corrupted worker rating and earnings display to ASCII-safe `star` and `Rs`
- Focused analyzer passed for `base_account_screen.dart` and `worker_account_screen.dart`.
- Account menu currently connects to:
  - Active Jobs
  - Job History
  - Messages
  - Earnings
  - Payout Methods
  - Transaction History
  - Professional Profile
  - Portfolio
  - Reviews & Ratings
  - Verification Status
  - App Settings

File:
- `lib/screens/account/worker_account_screen.dart`

## Worker Detail And Review Screens

Completed:
- Worker reviews screen cleanup completed:
  - `worker_reviews_screen.dart` is now a compatibility wrapper around the real Firestore-backed `RatingsReviewsScreen`
  - keeps `/worker-reviews` and `/worker/customer-reviews` route behavior intact
  - avoids maintaining duplicate worker review/rating UIs
- Worker job details screen rebuilt:
  - uses live Firestore booking stream instead of one-time future load
  - uses `WorkableDesign`, `WorkablePageHeader`, `WorkableSectionCard`, `WorkableStatusPill`, and `WorkableEmptyState`
  - preserves worker actions:
    - accept job
    - decline/cancel job
    - request completion
    - confirm cash received through `PaymentReconciliationService`
  - preserves verification gate before accepting jobs
  - keeps customer phone/address restricted when PAN/Aadhaar upload requirement is not met
  - shows clear job, customer, status, payment, and next-action cards
  - added loading lock and safer async error handling for job actions
  - focused analyzer passed for `worker_job_details_screen.dart` and `worker_reviews_screen.dart`

Files:
- `lib/screens/worker_job_details_screen.dart`
- `lib/screens/worker_reviews_screen.dart`

Remaining worker-side polish before rearchitecture:
- Completed:
  - `worker_edit_profile_screen.dart` is now a compatibility wrapper around `WorkerProfessionalProfileScreen`
    - keeps `/worker-edit-profile` route working
    - removes the old duplicate deep-purple basic profile editor
  - `worker_profile_update_screen.dart` is now a compatibility wrapper around `WorkerProfessionalProfileScreen`
    - keeps `/worker-profile-update` route working
    - removes the old duplicate update/profile-photo form and debug print
  - `worker_change_password_screen.dart` is now a compatibility wrapper around the polished shared `ChangePasswordScreen`
    - keeps `/worker-change-password` route working
    - avoids maintaining a weaker worker-only password duplicate
  - `worker_list_screen.dart` rebuilt:
    - uses shared `WorkableDesign`, `WorkablePageHeader`, `WorkableSectionCard`, `WorkableStatusPill`, `WorkableInfoRow`, and `WorkableEmptyState`
    - preserves navigation to `WorkerProfileScreen`
    - shows service fit, rating/new-worker state, completed jobs, location, and starting price
    - cleans corrupted rupee/star text to ASCII-safe display
  - Focused analyzer passed for all four worker-side screens.
- Remaining:
  - No high-priority worker-side polish screens remain from this batch.

Remaining settings/legal polish before rearchitecture:
- Completed:
  - `app_settings_screen.dart` targeted polish:
    - preserved real preference behavior for theme, notifications, location, font size, high contrast, storage/data, and reset settings
    - moved helper cards and settings rows closer to `WorkableDesign` tokens
  - `language_selection_screen.dart` rebuilt:
    - removed corrupted flag/native-language text
    - saves selected language through `AppPreferencesService`
    - adds clean search, selected language state, popular/more language grouping, and honest localization rollout note
  - `security_privacy_screen.dart` rebuilt:
    - uses shared `WorkableDesign`, `WorkablePageHeader`, `WorkableSectionCard`, and `WorkableStatusPill`
    - connects biometric login, auto-lock, and location features to `AppPreferencesService`
    - links to shared change-password, privacy policy, and terms screens
    - marks data export/delete-account workflows as planned instead of fake-functional
  - `privacy_policy_screen.dart` rebuilt:
    - structured marketplace privacy policy for account data, booking/payment/support data, worker trust data, visibility, sharing, and choices
    - uses shared UI components
  - `terms_conditions_screen.dart` rebuilt:
    - structured marketplace terms for usage, bookings, completion, payments, payouts, safety, disputes, and account action
    - uses shared UI components
  - Focused analyzer passed for all five settings/legal screens.

Architecture start condition:
- Start the Clean Architecture + Riverpod pilot now that the remaining worker-side and settings/legal polish batches are completed.
- First architecture pilot should still be notifications because it is isolated enough to prove the folder/provider/service pattern safely.

## Admin

Completed:
- Admin payment review screen added.
- Admin payout review screen added.
- Admin verification dashboard has shortcuts for:
  - payment review
  - payout review
- Worker verification review existed and worker onboarding now feeds it better through submitted status fields.

Files:
- `lib/screens/admin/admin_payment_review_screen.dart`
- `lib/screens/admin/admin_payout_review_screen.dart`
- `lib/screens/admin/admin_verification_dashboard.dart`
- `lib/screens/admin/verification_review_screen.dart`

## Verification / Analyzer Notes

Verification polish completed:
- Identity verification hub now uses `WorkableDesign` for shell, status card, tier chip, progress, verification items, quick actions, benefits, and support card.
- Removed corrupted/noisy debug `print` calls from identity verification and replaced necessary diagnostics with `debugPrint`.
- Government ID verification now uses `WorkableDesign` for shell, document cards, capture/review/result states, step indicator, and secure-note styling.
- Government ID selection no longer displays corrupted emoji icon strings; it uses clean `LucideIcons` based on document type.
- Verification child screen polish completed:
  - `phone_verification_screen.dart` rebuilt as a real Firebase SMS OTP flow:
    - removed fake call verification option
    - removed debug prints
    - updates Firebase Auth phone number and Firestore verification status
    - uses shared `WorkableDesign` and `WorkablePageHeader`
  - `email_verification_screen.dart` rebuilt as a real Firebase email-link flow:
    - removed fake 6-digit email code UI
    - removed local-only email edit behavior
    - supports secure current-email verification and pending new-email verification
    - writes pending/verified status to Firestore
    - uses shared `WorkableDesign` and `WorkablePageHeader`
  - `selfie_verification_screen.dart` rebuilt as a cleaner face-match flow:
    - instruction -> preview/retake -> submit -> under-review
    - uses front camera preference
    - returns `true` to the verification hub after submission
    - uses shared `WorkableDesign` and shared UI components
  - `address_verification_screen.dart` flow improved:
    - selecting a proof no longer auto-uploads immediately
    - user now previews the selected document and explicitly submits for review
    - tracks selected-vs-submitted document state
    - added shared premium header and safer async mounted guards
  - `pan_card_verification_screen.dart` cleanup:
    - uses `WorkableDesign.canvas` and primary token in key actions
    - returns to verification hub with result instead of route-replacing the stack
    - fixed failed-submit path so it no longer continues into the pending/success step
    - added async mounted guards
  - `police_certificate_screen.dart` cleanup:
    - uses `WorkableDesign.canvas` and primary token in key actions
    - returns to verification hub with result instead of route-replacing the stack
    - added async mounted guards
- Preserved verification logic:
  - status listener
  - tier progress
  - worker visibility sync
  - Aadhaar/government ID routing
  - OCR extraction
  - document validation
  - verification upload
- Focused analyzer passed for `identity_verification_screen.dart`, `government_id_verification_screen.dart`, and the six verification child screens:
  - `pan_card_verification_screen.dart`
  - `address_verification_screen.dart`
  - `selfie_verification_screen.dart`
  - `phone_verification_screen.dart`
  - `email_verification_screen.dart`
  - `police_certificate_screen.dart`

Focused analyzer checks passed after major changes:
- Entry/auth redesign.
- Worker signup/onboarding flow.
- Worker visibility panel integration.
- Worker dashboard real-data upgrade.
- Worker earnings/payout upgrade.

Known wider-project note:
- Full project may still contain old legacy warnings in unrelated files.
- We added analyzer exclude for stale nested project copy.

## Next Best Work When Quota Resets

Priority order:

1. Worker payout methods screen polish
   - Completed.

2. Worker active jobs screen polish
   - Completed.

3. Worker job history polish
   - Completed.

4. Worker professional profile polish
   - Completed.

5. Customer payment/detail polish
   - Completed.

6. Generic Help Request backbone
   - First backbone completed.
   - Next: worker-side open help requests list and accept flow.

7. AI service diagnosis and smart booking assistant
   - Customer can type/speak/upload image.
   - AI suggests category, urgency, price range, and best workers.

## Important Reminder

Before starting next work:
1. Read this file.
2. Inspect the target page/service.
3. Check whether a partial implementation already exists.
4. Upgrade or connect existing work instead of duplicating it.
5. Run focused `dart analyze` on touched files.
