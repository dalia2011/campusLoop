# Student event screens (7–20) with mock data

This change adds the student event journey on top of the auth screens: Explore, search, filters, event detail, registration, My Events, ticket, cancel and waitlist. The backend and its Swagger are not available yet, so everything runs against an in-memory mock repository. A real API repository is already written behind the same interface.

## Screens

| # | Screen | Where |
|---|--------|-------|
| 7 | Explore feed (topic chips, filter bar, active filter chips) | `features/events/ui/explore_screen.dart` |
| 8–9 | Search with recent searches, results | `ui/search_screen.dart` |
| 10 | Filters bottom sheet (topic, date, availability) | `ui/widgets/filter_widgets.dart` |
| 11 | No-results state | `ui/widgets/results_scroll_view.dart` |
| 12 | Event detail (available, full, registered, waitlisted, checked in, canceled, ended, closed) | `ui/event_detail_screen.dart` |
| 13 | Join waitlist | event detail + `confirm_registration_screen.dart` |
| 14 | Confirm your place | `ui/confirm_registration_screen.dart` |
| 15 | Registered success | `ui/registered_screen.dart` |
| 16–17 | My Events: Registered, Saved, Past | `ui/my_events_screen.dart` |
| 18 | Ticket with QR code | `ui/ticket_screen.dart` |
| 19 | Cancel registration confirmation sheet | `core/widgets/confirmation_sheet.dart` |
| 20 | Waitlisted state | `ui/waitlist_screen.dart` |

A new tab shell (`features/shell/main_shell.dart`) holds Explore, My Events, Alerts (placeholder) and Profile (placeholder). `AuthGate` now opens it once signed in.

## Network layer and mock data

- `EventsRepository` is an abstract class. `MockEventsRepository` and `ApiEventsRepository` implement it.
- `AppConfig.useMockApi` picks the implementation. Run against a real backend with `--dart-define=USE_MOCK_API=false`.
- The mock seeds events relative to the current time, simulates latency, and has an `offline` switch. It covers the awkward cases: a full event, a last seat that disappears while confirming (`EVENT_FULL`), a canceled event, a completed and checked-in event, and promotion from the waitlist when someone cancels.
- Registration sends one `Idempotency-Key` per user action and reuses it on retry. A new key is generated when the action changes (register, then join waitlist).
- Every guess about the API is marked `ASSUMPTION` in `api_events_repository.dart`. Reconcile these when the Swagger arrives:
  - register body `{"joinWaitlist": bool}`, 409 `EVENT_FULL` when full and the flag is false
  - `GET /me/events?filter=registered|saved|past` returning `{items}`
  - `GET /events/:id/ticket`
  - `available=true` query parameter
  - JSON field names (`waitlistPosition`, `isSaved`, `organizerName`, `checkedInAt`)

## State

- `ExploreController` is owned by the Explore tab, which sits in an `IndexedStack`, so search text and filters survive opening an event and going back.
- 300 ms search debounce, cursor pagination (20 per page), protection against out-of-order responses, stale data kept with an offline banner and Retry, in-memory recent searches.
- The repository exposes `changes` so screens refresh after a registration, cancel or save.

## Shared pieces

`core/widgets/` adds `StatusBadge`, `EmptyState`, `OfflineBanner`, `showConfirmationSheet`, toasts and static skeletons. `core/format/date_format.dart` holds the date formatting. `ApiException.from` wraps any error into the app's error type.

## Accessibility

- Status badges carry an icon and text, never color alone.
- Selected chips show a checkmark.
- Tap targets are at least 44 pt.
- Semantics labels, headers and live regions are set on the new screens.

## Tests

- `test/features/events/mock_events_repository_test.dart`: paging, search, filters, registration, idempotency, waitlist, cancel and promotion, tickets, offline.
- `test/features/events/events_flow_test.dart`: 12 phone-sized widget flows (reserve, waitlist, last seat taken, no results, recents, filters, offline, My Events, unsave, cancel, leave waitlist).
- Auth and app tests were updated for the new tab shell.
- Dependency added: `qr_flutter`.

`flutter analyze` is clean and all 67 tests pass.

## Not done yet

Alerts (21–22), Profile and preferences (23–24), offline screen polish (25), organizer screens (26–35), a disk cache for offline use, and switching to the real API once the Swagger is available.
