#!/usr/bin/env bash
# Smoke-test the invitation + customer-side flow end-to-end against a
# running backend. Hits the real API, no mocks.
#
# What it exercises:
#   1. Owner registers + logs in
#   2. Customer registers (different email)
#   3. Owner sends a bare-email invite addressed to the customer's email
#   4. Customer reads /notifications (should see one INVITE_RECEIVED)
#   5. Customer reads /invitations/incoming (should see PENDING invite)
#   6. Customer accepts
#   7. Customer reads /me/links — should now have one linked party
#   8. (Optional) merchant lists outgoing invites; should be ACCEPTED
#
# Usage:
#   API_BASE=http://localhost:3001 ./scripts/smoke-invite-flow.sh
#
# Requires: bash, curl, jq.

set -euo pipefail

API="${API_BASE:-http://localhost:3001}"
TS=$(date +%s)
OWNER_EMAIL="owner+${TS}@smoke.test"
CUST_EMAIL="customer+${TS}@smoke.test"
PASS='Smoke1234'

echo "▸ API base: $API"
echo "▸ Owner email:    $OWNER_EMAIL"
echo "▸ Customer email: $CUST_EMAIL"
echo

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

# ── 1) Owner registers
bold "[1/8] Owner register"
OWNER_REG=$(curl -fsS -X POST "$API/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"Smoke Owner\",\"email\":\"$OWNER_EMAIL\",\"password\":\"$PASS\"}") \
  || fail "Owner registration failed"
OWNER_TOKEN=$(echo "$OWNER_REG" | jq -r .accessToken)
OWNER_ID=$(echo "$OWNER_REG" | jq -r .user.id)
echo "  user_id=$OWNER_ID"

# ── 2) Customer registers (does NOT yet exist when invite is sent — to
# stress the claim-at-signup path, we'd reverse this. For the simple
# case we register first so the invite resolves toUserId immediately.)
bold "[2/8] Customer register"
CUST_REG=$(curl -fsS -X POST "$API/auth/register" \
  -H 'Content-Type: application/json' \
  -d "{\"name\":\"Smoke Customer\",\"email\":\"$CUST_EMAIL\",\"password\":\"$PASS\"}") \
  || fail "Customer registration failed"
CUST_TOKEN=$(echo "$CUST_REG" | jq -r .accessToken)
CUST_ID=$(echo "$CUST_REG" | jq -r .user.id)
echo "  user_id=$CUST_ID"

# ── 3) Owner sends a bare-email invite (no pre-existing party)
bold "[3/8] Owner sends bare-email invite"
INVITE=$(curl -fsS -X POST "$API/invitations" \
  -H "Authorization: Bearer $OWNER_TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
        \"toEmail\":\"$CUST_EMAIL\",
        \"linkType\":\"PARTY\",
        \"displayName\":\"Smoke Customer\",
        \"message\":\"Smoke test invite\"
      }") || fail "Send invite failed"
INVITE_ID=$(echo "$INVITE" | jq -r .id)
INVITE_STATUS=$(echo "$INVITE" | jq -r .status)
INVITE_PARTY=$(echo "$INVITE" | jq -r .partyId)
echo "  invitation_id=$INVITE_ID status=$INVITE_STATUS partyId=$INVITE_PARTY"
[[ "$INVITE_STATUS" == "PENDING" ]] || fail "Expected PENDING, got $INVITE_STATUS"
[[ "$INVITE_PARTY" == "null" ]] || fail "Expected null partyId (bare-email invite)"

# ── 4) Customer reads /notifications
bold "[4/8] Customer reads notifications"
NOTIFS=$(curl -fsS "$API/notifications" \
  -H "Authorization: Bearer $CUST_TOKEN")
NOTIF_COUNT=$(echo "$NOTIFS" | jq '.data | length')
NOTIF_UNREAD=$(echo "$NOTIFS" | jq .unread)
echo "  notifications=$NOTIF_COUNT unread=$NOTIF_UNREAD"
[[ "$NOTIF_COUNT" -ge 1 ]] || fail "Expected at least 1 notification"
[[ "$NOTIF_UNREAD" -ge 1 ]] || fail "Expected at least 1 unread notification"

# ── 5) Customer reads /invitations/incoming
bold "[5/8] Customer reads incoming invitations"
INCOMING=$(curl -fsS "$API/invitations/incoming?status=PENDING" \
  -H "Authorization: Bearer $CUST_TOKEN")
INC_COUNT=$(echo "$INCOMING" | jq '.data | length')
INC_FIRST_ID=$(echo "$INCOMING" | jq -r '.data[0].id')
echo "  pending=$INC_COUNT first_id=$INC_FIRST_ID"
[[ "$INC_FIRST_ID" == "$INVITE_ID" ]] || fail "Inbox didn't surface our invite"

# ── 6) Customer accepts
bold "[6/8] Customer accepts invitation"
ACCEPTED=$(curl -fsS -X POST "$API/invitations/$INVITE_ID/accept" \
  -H "Authorization: Bearer $CUST_TOKEN")
ACC_STATUS=$(echo "$ACCEPTED" | jq -r .status)
ACC_PARTY=$(echo "$ACCEPTED" | jq -r .partyId)
echo "  status=$ACC_STATUS partyId=$ACC_PARTY"
[[ "$ACC_STATUS" == "ACCEPTED" ]] || fail "Expected ACCEPTED, got $ACC_STATUS"
[[ "$ACC_PARTY" != "null" ]] || fail "Expected a partyId after lazy-create"

# ── 7) Customer reads /me/links — should now have one linked party
bold "[7/8] Customer reads /me/links"
LINKS=$(curl -fsS "$API/me/links" -H "Authorization: Bearer $CUST_TOKEN")
LINK_COUNT=$(echo "$LINKS" | jq '.parties | length')
LINK_NAME=$(echo "$LINKS" | jq -r '.parties[0].name')
echo "  parties=$LINK_COUNT first_name=$LINK_NAME"
[[ "$LINK_COUNT" -ge 1 ]] || fail "Expected at least one linked party"

# ── 8) Owner sees outgoing invite as ACCEPTED
bold "[8/8] Owner reads outgoing invitations"
OUTGOING=$(curl -fsS "$API/invitations/outgoing?status=ACCEPTED" \
  -H "Authorization: Bearer $OWNER_TOKEN")
OUT_FIRST=$(echo "$OUTGOING" | jq -r '.data[0].status')
echo "  first.status=$OUT_FIRST"
[[ "$OUT_FIRST" == "ACCEPTED" ]] || fail "Owner didn't see the accepted state"

bold "✅ All 8 steps passed."
