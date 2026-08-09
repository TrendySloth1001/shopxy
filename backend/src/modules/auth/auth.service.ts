import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { Role } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { invitationsService, notifyInviteExpired } from '../invitations/invitations.service.js';
import { notificationsService } from '../notifications/notifications.service.js';
import { logger } from '../../shared/logging/logger.js';
import {
  JWT_ACCESS_SECRET as ACCESS_SECRET,
  JWT_REFRESH_SECRET as REFRESH_SECRET,
} from '../../shared/authSecrets.js';
import { bumpTokensValidFromCache } from '../../shared/http/requireAuth.js';
import { normalizeRights } from '../../shared/http/permissions.js';
import { seedDefaultRoles } from '../team/team.service.js';
import {
  loginLockRemainingMs,
  recordLoginFailure,
  clearLoginFailures,
} from './loginThrottle.js';
import { isPasswordBreached } from './passwordBreach.js';
import { revokeSession } from '../../shared/sessionRevocation.js';
import { totpService } from './totp.service.js';
import { verifyGoogleIdToken } from './googleAuth.js';
import { maskIp, type DeviceContext } from './deviceContext.js';
// Imported only to say WHICH half of the OTP gate is down when signup is
// blocked — "verification unavailable" is useless in a log without it.
import { redisAvailable } from '../../infra/redis.js';
import { mailerEnabled } from '../../infra/mailer.js';
import {
  canVerifyEmail,
  generateOtp,
  sendOtpEmail,
  putPending,
  getPending,
  dropPending,
  verifyOtp,
  resendCooldownRemaining,
  markResent,
} from './emailVerification.js';
import {
  sendResetOtpEmail,
  putPendingReset,
  verifyResetOtp,
  dropPendingReset,
  resetCooldownRemaining,
  markResetSent,
} from './passwordReset.js';

const REFRESH_EXPIRES_MS = 7 * 24 * 60 * 60 * 1000;
// Device-remember credential lifetime (sliding — renewed on each use).
const REMEMBER_EXPIRES_MS = 30 * 24 * 60 * 60 * 1000;
const MAX_REMEMBER_TOKENS_PER_USER = 10;

const safeUserSelect = {
  id: true,
  email: true,
  name: true,
  role: true,
  isPlatformAdmin: true,
  isActive: true,
  emailNotifications: true,
  shopName: true,
  shopAddress: true,
  shopCity: true,
  shopState: true,
  shopStateCode: true,
  shopPinCode: true,
  shopGstin: true,
  gstEffectiveFrom: true,
  registrationType: true,
  shopPan: true,
  upiVpa: true,
  avatarUrl: true,
  phoneNumber: true,
  notifyOrders: true,
  notifyDeals: true,
  notifyAccount: true,
  notifyMessages: true,
  pushEnabled: true,
  smsEnabled: true,
  acceptedAt: true,
  // Not a secret (it's Google's stable per-account `sub`, useless without
  // also owning the Google account) — clients derive "does this account
  // need a recovery PIN?" from `googleId != null && recoveryPinSetAt ==
  // null`, since that combination can't be told apart from a plain
  // password account any other way (Google-only accounts get a random,
  // unusable passwordHash rather than a nullable column — see the schema
  // comment on `googleId`).
  googleId: true,
  // Timestamp only, never the hash — lets clients derive "PIN already set
  // up?" without exposing anything guessable.
  recoveryPinSetAt: true,
  createdAt: true,
} as const;

async function signAccess(
  userId: number,
  email: string,
  role: Role,
  isPlatformAdmin: boolean,
  sid: string,
): Promise<string> {
  // shopId/shopRole are NOT baked into the JWT: requireAuth always
  // re-resolves membership for OWNER accounts (so a role change takes
  // effect within the cache TTL without re-login), which means a baked
  // value would only ever be overwritten. Dropping the sign-time
  // ShopMember lookup removes a wasted query on every token mint
  // (B-AUTH-7). `sid` ties this token to its refresh-token family so a
  // single-device logout can revoke it (see sessionRevocation.ts).
  return jwt.sign(
    { sub: userId, email, role, isPlatformAdmin, sid },
    ACCESS_SECRET,
    { expiresIn: '15m' },
  );
}

/**
 * Mint an access+refresh pair for one device session. Single source of truth
 * for the `signAccess` + `createRefreshToken` pairing that every login path
 * (login/register/accept-invite/remember) and the rotation path share. The
 * `family` is the session id: omitted starts a fresh session, passed keeps the
 * caller's lineage (used by `refresh` so `sid` is stable across rotation).
 */
async function issueSession(
  user: { id: number; email: string; role: Role; isPlatformAdmin: boolean },
  family?: string,
  device?: DeviceContext,
): Promise<{ accessToken: string; refreshToken: string }> {
  const sid = family ?? crypto.randomUUID();
  const accessToken = await signAccess(user.id, user.email, user.role, user.isPlatformAdmin, sid);
  const refreshToken = await createRefreshToken(user.id, sid, device);
  return { accessToken, refreshToken };
}

const MAX_ACTIVE_REFRESH_TOKENS_PER_USER = 5;

/**
 * Development escape hatch for the mandatory signup OTP.
 *
 * Local dev and the test suite usually have neither Redis nor a mail
 * transport, and blocking every signup there would make the app unusable
 * offline. Opting out is explicit — you have to set the flag — and it is
 * **refused outright in production**, so the guarantee that a password
 * account cannot exist unverified can't be weakened by a stray env var on a
 * real deployment. Prefer configuring SMTP locally (see `infra/mailer.ts`)
 * over setting this.
 */
function unverifiedSignupAllowed(): boolean {
  return (
    process.env.ALLOW_UNVERIFIED_SIGNUP === 'true' &&
    process.env.NODE_ENV !== 'production'
  );
}

/// SHA-256 hex of a refresh token. We persist only this digest, never
/// the raw JWT, so a read-only DB leak can't be replayed as a live
/// session (B-AUTH-1). Lookups hash the presented token and match it.
function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

/// Issues a refresh token and stores its hash. `family` ties the token
/// to a rotation lineage: a fresh login starts a new family; a rotation
/// keeps the parent's family so reuse of an already-rotated token can be
/// traced back and the whole family revoked (B-AUTH-2).
async function createRefreshToken(
  userId: number,
  family?: string,
  device?: DeviceContext,
): Promise<string> {
  const jti = crypto.randomUUID();
  const fam = family ?? crypto.randomUUID();
  const token = jwt.sign({ sub: userId, jti, family: fam }, REFRESH_SECRET, {
    expiresIn: '7d',
  });
  const expiresAt = new Date(Date.now() + REFRESH_EXPIRES_MS);
  await prisma.refreshToken.create({
    data: {
      token: hashToken(token),
      family: fam,
      userId,
      expiresAt,
      userAgent: device?.userAgent?.slice(0, 400) ?? null,
      deviceName: device?.deviceName?.slice(0, 120) ?? null,
      ipMasked: maskIp(device?.ip),
      lastUsedAt: new Date(),
    },
  });

  // Cap the number of active sessions per user. If we're now over the limit,
  // drop the oldest tokens (FIFO by createdAt). Keeps a forgotten device or
  // a stolen-cookie attacker from accumulating indefinite footholds.
  const active = await prisma.refreshToken.findMany({
    where: { userId },
    orderBy: { createdAt: 'asc' },
    select: { id: true },
  });
  if (active.length > MAX_ACTIVE_REFRESH_TOKENS_PER_USER) {
    const excess = active.slice(0, active.length - MAX_ACTIVE_REFRESH_TOKENS_PER_USER);
    await prisma.refreshToken.deleteMany({
      where: { id: { in: excess.map((t) => t.id) } },
    });
  }

  return token;
}

/// Lower-cases, collapses non-alphanumerics to single dashes, trims
/// leading/trailing dashes. Mirrors shop.service.ts's slugify — kept
/// inline here so auth doesn't cross-depend on the shop module.
function slugifyShop(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/// Returns `base`, `base-2`, `base-3`, … until a slug is free. Same
/// algorithm as shop.service.ts's `uniqueSlug`; duplicated rather than
/// imported to keep the auth module standalone.
async function uniqueShopSlug(base: string): Promise<string> {
  let candidate = base || 'shop';
  let suffix = 1;
  for (;;) {
    const existing = await prisma.shop.findUnique({
      where: { slug: candidate },
      select: { id: true },
    });
    if (!existing) return candidate;
    suffix += 1;
    candidate = `${base}-${suffix}`;
  }
}

/// Thrown inside acceptTeamInvite's transaction when the single-use
/// status claim loses a race (double submit) — rolls the new account +
/// membership back so one invite can't mint two staffers.
class InviteAlreadyUsedError extends Error {
  constructor() {
    super('INVITE_ALREADY_USED');
    this.name = 'InviteAlreadyUsedError';
  }
}

export class AuthService {
  /**
   * Start registration. Validates the email + password, then **gates on an
   * emailed OTP**: the signup is held in Redis (no `User` row yet) and a code
   * is emailed; the account is only created by {@link verifyEmailOtp}. This is
   * what stops unverified/stale accounts from piling up in the DB.
   *
   * If the OTP infra (Redis + mailer) is down we fall back to creating the
   * account directly so signups aren't blocked by an outage — the caller can
   * tell which happened: a `{ pending: true }` result means "collect the OTP",
   * a `{ user, accessToken, … }` result means "already signed in".
   */
  async register(
    data: {
      email: string;
      name: string;
      password: string;
      role: Role;
      shopName?: string;
    },
    device?: DeviceContext,
  ) {
    const email = data.email.toLowerCase().trim();
    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) return { error: 'Email already registered' as const };
    if (await isPasswordBreached(data.password)) {
      return { error: 'password_breached' as const };
    }

    const passwordHash = await bcrypt.hash(data.password, 12);
    const name = data.name.trim();
    const role: Role = data.role === 'OWNER' ? 'OWNER' : 'CUSTOMER';
    const shopName = (data.shopName ?? '').trim() || undefined;

    // Email-OTP gate — MANDATORY for password signups. The signup is held in
    // Redis and the User row is minted only once the code is confirmed, so an
    // unverified password account cannot exist.
    //
    // There is deliberately NO fallback to direct creation. It used to fall
    // through to `_finalizeRegistration` when the OTP infra was unavailable,
    // which meant a missing mail transport silently downgraded the guarantee
    // to nothing — and did so without an error anyone would notice. An outage
    // now blocks signup loudly instead.
    //
    // Google SSO does not come through here (see `googleAuth`): Google has
    // already verified the address, so there is nothing for an OTP to add.
    if (!canVerifyEmail()) {
      if (unverifiedSignupAllowed()) {
        logger.warn(
          { event: 'otp_bypassed_dev', email },
          'ALLOW_UNVERIFIED_SIGNUP is on — creating the account without email verification',
        );
        return this._finalizeRegistration({ email, name, passwordHash, role, shopName }, device);
      }
      logger.error(
        { event: 'otp_unavailable', redis: redisAvailable(), mailer: mailerEnabled() },
        'Signup blocked: email verification is unavailable',
      );
      return { error: 'verification_unavailable' as const };
    }

    const otp = generateOtp();
    if (!(await sendOtpEmail(email, name, otp))) {
      logger.error({ event: 'otp_send_failed', email }, 'Signup blocked: OTP email failed to send');
      return { error: 'verification_unavailable' as const };
    }
    await putPending({ name, email, passwordHash, role, shopName }, otp);
    return { pending: true as const, email };
  }

  /** Confirm the emailed OTP → create the account + sign in. */
  async verifyEmailOtp(email: string, otp: string, device?: DeviceContext) {
    const norm = email.toLowerCase().trim();
    const res = await verifyOtp(norm, otp);
    if (!res.ok) return { error: res.reason };
    // Race guard: the email could have been registered by another attempt
    // while this one was pending.
    const existing = await prisma.user.findUnique({ where: { email: norm } });
    if (existing) {
      await dropPending(norm);
      return { error: 'Email already registered' as const };
    }
    const p = res.pending;
    const result = await this._finalizeRegistration(
      { email: p.email, name: p.name, passwordHash: p.passwordHash, role: p.role, shopName: p.shopName },
      device,
    );
    await dropPending(norm);
    return result;
  }

  /** Re-send the verification code for a still-pending signup (rate-limited). */
  async resendEmailOtp(email: string) {
    const norm = email.toLowerCase().trim();
    const pending = await getPending(norm);
    if (!pending) return { error: 'expired' as const };
    const cd = await resendCooldownRemaining(norm);
    if (cd > 0) return { error: 'cooldown' as const, retryAfterS: cd };
    const otp = generateOtp();
    if (!(await sendOtpEmail(norm, pending.name, otp))) {
      return { error: 'send_failed' as const };
    }
    await putPending(
      {
        name: pending.name,
        email: pending.email,
        passwordHash: pending.passwordHash,
        role: pending.role,
        shopName: pending.shopName,
      },
      otp,
    );
    await markResent(norm);
    return { ok: true as const };
  }

  /**
   * Create the User (+ Shop/team for a named-shop OWNER), claim pending
   * invites and mint a session. Shared by direct signup and OTP-verified
   * signup — the single place account creation actually happens.
   */
  private async _finalizeRegistration(
    data: { email: string; name: string; passwordHash: string; role: Role; shopName?: string },
    device?: DeviceContext,
  ) {
    const { email, name, passwordHash } = data;
    const acceptedAt = new Date();

    // A pending TEAM invite for this email takes precedence over creating a
    // shop. The person was invited to join an existing shop's team, so even
    // when the merchant app sends role=OWNER + a shopName we must NOT mint
    // them their own shop: ShopMember.userId is unique, so owning a shop
    // would permanently block them from ever accepting the invite
    // (respond() throws ALREADY_ON_TEAM once any membership exists). Instead
    // we onboard them as staff of the inviting shop, atomically — the same
    // outcome as the token-based accept-invite screen, for people who just
    // hit "register" without the invite link. Customer-app (role=CUSTOMER)
    // signups keep the invite PENDING for explicit in-app acceptance.
    let user;
    // SECURITY (AUTH-1): a pending TEAM invite for this email is NOT
    // auto-claimed here. Granting a ShopMember seat from an email match alone
    // let anyone who knew (or guessed) an invited address register it and
    // seize a staff seat in the inviting shop — with no proof of mailbox
    // ownership (confirmed exploitable). Team membership is now granted ONLY
    // through the token-based accept flow (POST /auth/accept-invite), where
    // possession of the per-invite link/token proves the recipient actually
    // received the invitation.
    //
    // We still DETECT a pending team invite so we don't mint this person their
    // own shop: ShopMember.userId is unique, so owning a shop would
    // permanently block them from accepting the invite via the token link. A
    // signup against an invited email therefore creates a shopless account and
    // leaves the invite PENDING for the link-based accept.
    const hasPendingTeamInvite =
      data.role === 'OWNER'
        ? (await prisma.invitation.count({
            where: {
              toEmail: email,
              toUserId: null,
              linkType: 'TEAM',
              status: 'PENDING',
              expiresAt: { gt: new Date() },
            },
          })) > 0
        : false;

    const shopName = (data.shopName ?? '').trim();
    if (!user && data.role === 'OWNER' && shopName && !hasPendingTeamInvite) {
      const slug = await uniqueShopSlug(slugifyShop(shopName));
      user = await prisma.$transaction(async (tx) => {
        const created = await tx.user.create({
          data: {
            email,
            name,
            passwordHash,
            role: 'OWNER',
            // Mirror the shop name into the User so invoice headers /
            // GST footers have a value to render without a follow-up
            // Shop lookup. The merchant can later refine the legal name
            // separately from the public shop name in settings.
            shopName,
            acceptedAt,
          },
          select: safeUserSelect,
        });
        const shop = await tx.shop.create({
          data: {
            ownerUserId: created.id,
            name: shopName,
            slug,
          },
          select: { id: true },
        });
        // Seed the owner's team membership in the same transaction.
        // shopId/shopRole now resolve from ShopMember, so without this
        // row a brand-new owner couldn't reach their own shop.
        await tx.shopMember.create({
          data: { shopId: shop.id, userId: created.id, role: 'OWNER' },
        });
        // Seed the shop's starter roles (Manager/Stockist/Cashier) so the
        // Team & roles screen is populated from day one.
        await seedDefaultRoles(tx, shop.id);
        return created;
      });
    } else if (!user) {
      // No shop created at signup. A merchant (role=OWNER) who didn't send a
      // shopName is created shopless and names their shop on the onboarding
      // screen next (POST /me/onboarding/shop); a customer stays a customer.
      // Either way no Shop/ShopMember row is created here.
      user = await prisma.user.create({
        data: {
          email,
          name,
          passwordHash,
          role: data.role === 'OWNER' ? 'OWNER' : 'CUSTOMER',
          // DPDP §6: record the moment of consent. The controller enforces
          // that both terms + privacy were ticked before reaching the
          // service, so reaching here implies a freely-given consent.
          acceptedAt,
        },
        select: safeUserSelect,
      });
    }

    // Attach any pending invitations addressed to this email so the new
    // user sees them on first login. Best-effort — a failure here must
    // not block account creation.
    try {
      await invitationsService.claimPendingForNewUser({ userId: user.id, email });
    } catch (err) {
      // Stable `event` tag so alerts can match without parsing free-form text.
      // pino emits JSON natively so a single structured call covers both the
      // human-readable warn and the machine-readable error record we used to
      // emit as two separate console calls.
      logger.error({ event: 'invitation_claim_failed', userId: user.id, err }, 'invitation claim failed');
    }

    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    return { user, accessToken, refreshToken };
  }

  /// Read-only view of a TEAM invitation by its token, for the staff
  /// accept-invite screen ("<Shop> invited you to join as Manager").
  /// Returns a friendly error string for unusable tokens so the screen
  /// can explain why rather than 404.
  async previewTeamInvite(token: string) {
    const invite = await prisma.invitation.findUnique({
      where: { token },
      select: {
        toEmail: true,
        teamRoleName: true,
        linkType: true,
        status: true,
        expiresAt: true,
        fromShopName: true,
      },
    });
    if (!invite || invite.linkType !== 'TEAM') {
      return { error: 'This invitation link is not valid.' as const };
    }
    if (invite.status !== 'PENDING') {
      return { error: 'This invitation has already been used.' as const };
    }
    if (invite.expiresAt < new Date()) {
      return { error: 'This invitation has expired.' as const };
    }
    return {
      invite: {
        email: invite.toEmail,
        roleLabel: invite.teamRoleName ?? 'Staff',
        shopName: invite.fromShopName,
      },
    };
  }

  /// Brand-new staffer accepts a TEAM invite and sets up their account
  /// in one step: validates the token, creates a shopless merchant
  /// (role=OWNER) account, makes them a ShopMember with the invited
  /// role, and marks the invite accepted — atomically. No tokensValidFrom
  /// bump (there are no prior sessions to revoke), so the freshly-minted
  /// access token isn't immediately invalidated. Existing accounts use
  /// the in-app notification accept flow instead.
  async acceptTeamInvite(
    data: { token: string; name?: string; password: string },
    device?: DeviceContext,
  ) {
    const invite = await prisma.invitation.findUnique({
      where: { token: data.token },
      select: {
        id: true,
        shopId: true,
        toEmail: true,
        teamRoleName: true,
        teamPermissions: true,
        linkType: true,
        status: true,
        expiresAt: true,
        fromUserId: true,
        displayName: true,
      },
    });
    if (!invite || invite.linkType !== 'TEAM' || !invite.teamRoleName) {
      return { error: 'This invitation link is not valid.' as const };
    }
    if (invite.status !== 'PENDING') {
      return { error: 'This invitation has already been used.' as const };
    }
    if (invite.expiresAt < new Date()) {
      const flipped = await prisma.invitation.updateMany({
        where: { id: invite.id, status: 'PENDING' },
        data: { status: 'EXPIRED' },
      });
      if (flipped.count > 0) await notifyInviteExpired(prisma, invite);
      return { error: 'This invitation has expired.' as const };
    }
    const email = invite.toEmail.toLowerCase().trim();
    const existing = await prisma.user.findUnique({ where: { email }, select: { id: true } });
    if (existing) {
      return {
        error:
          'An account with this email already exists. Sign in and accept from your notifications.' as const,
      };
    }
    if (await isPasswordBreached(data.password)) {
      return { error: 'password_breached' as const };
    }

    const passwordHash = await bcrypt.hash(data.password, 12);
    const teamRoleName = invite.teamRoleName;
    // Default the name from the email local part when not supplied, so an
    // account that isn't fully set up still has a sensible label.
    const finalName = data.name?.trim() || email.split('@')[0];
    let user;
    try {
      user = await prisma.$transaction(async (tx) => {
        // Single-use claim: flip PENDING→ACCEPTED first so a double
        // submit can't create two accounts off one invite.
        const claim = await tx.invitation.updateMany({
          where: { id: invite.id, status: 'PENDING' },
          data: { status: 'ACCEPTED', respondedAt: new Date() },
        });
        if (claim.count === 0) throw new InviteAlreadyUsedError();

        const created = await tx.user.create({
          data: {
            email,
            name: finalName,
            passwordHash,
            role: 'OWNER',
            acceptedAt: new Date(),
          },
          select: safeUserSelect,
        });
        await tx.invitation.update({
          where: { id: invite.id },
          data: { toUserId: created.id },
        });
        await tx.shopMember.create({
          data: {
            shopId: invite.shopId,
            userId: created.id,
            role: 'STAFF',
            roleName: teamRoleName,
            permissions: normalizeRights(invite.teamPermissions),
          },
        });
        await tx.notification.create({
          data: {
            userId: invite.fromUserId,
            kind: 'INVITE_ACCEPTED',
            title: `${invite.toEmail} joined your team`,
            body: `As ${teamRoleName}`,
            data: { invitationId: invite.id, linkType: 'TEAM' },
          },
        });
        return created;
      });
    } catch (err) {
      if (err instanceof InviteAlreadyUsedError) {
        return { error: 'This invitation has already been used.' as const };
      }
      throw err;
    }

    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    return { user, accessToken, refreshToken };
  }

  async login(email: string, password: string, totpCode?: string, device?: DeviceContext) {
    const normEmail = email.toLowerCase().trim();

    // Per-account throttle: refuse before touching the DB or bcrypt once this
    // account has failed too many times recently (see loginThrottle.ts).
    const lockedMs = await loginLockRemainingMs(normEmail);
    if (lockedMs > 0) {
      return { error: 'locked' as const, retryAfterMs: lockedMs };
    }

    // Read the full row (incl. passwordHash + isActive) for the credential
    // check, but only ever return the `safeUserSelect` projection so the
    // wire response matches register/getMe and can't leak internal columns
    // like tokensValidFrom (B-AUTH-5).
    const user = await prisma.user.findUnique({
      where: { email: normEmail },
    });
    // Constant-time compare even for missing users (prevent user enumeration)
    const dummyHash = '$2b$12$invalidhashpadding000000000000000000000000000000000000';
    const valid = user
      ? await bcrypt.compare(password, user.passwordHash)
      : await bcrypt.compare(password, dummyHash).then(() => false);

    if (!user || !user.isActive || !valid) {
      // Count the miss (may escalate into a lock) before returning the same
      // opaque error — the throttle key is enumeration-neutral.
      await recordLoginFailure(normEmail);
      return { error: 'Invalid email or password' as const };
    }

    // Password is correct — now enforce 2FA if this account has it enabled.
    if (user.totpEnabledAt) {
      if (!totpCode) {
        // Don't clear the throttle yet and don't issue tokens: the client must
        // come back with a code. Password was right, so this isn't a failure.
        return { error: '2fa_required' as const };
      }
      const okTotp = await totpService.verifyForLogin(user.id, totpCode);
      if (!okTotp) {
        // A wrong second factor counts as a failed attempt (brute-force guard).
        await recordLoginFailure(normEmail);
        return { error: '2fa_invalid' as const };
      }
    }

    // Genuine success — wipe the failure/escalation state for this account.
    await clearLoginFailures(normEmail);

    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    const safeUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: safeUserSelect,
    });
    return { user: safeUser, accessToken, refreshToken };
  }

  /**
   * Sign in via a verified Google ID token — creates the account on first
   * use, links it to an existing email/password account if one matches
   * (Google's verified-email guarantee makes that safe), or just signs in
   * if the link already exists. Merchant-only for now (role OWNER,
   * shopless — named on the onboarding screen next, same as a password
   * signup without a shopName).
   */
  async googleAuth(idToken: string, device?: DeviceContext) {
    const profile = await verifyGoogleIdToken(idToken);
    if (!profile) return { error: 'invalid_google_token' as const };

    let user = await prisma.user.findUnique({ where: { googleId: profile.googleId } });

    if (!user) {
      const existing = await prisma.user.findUnique({ where: { email: profile.email } });
      if (existing) {
        user = await prisma.user.update({
          where: { id: existing.id },
          data: { googleId: profile.googleId },
        });
      } else {
        // Brand-new account. There's no password to set, so mint a random,
        // unusable one (same trick `pseudonymiseAccount` uses below) rather
        // than making `passwordHash` nullable and touching every
        // password-login codepath for a case that only ever authenticates
        // via Google or the recovery PIN.
        const passwordHash = await bcrypt.hash(crypto.randomUUID(), 12);
        const created = await this._finalizeRegistration(
          { email: profile.email, name: profile.name, passwordHash, role: 'OWNER' },
          device,
        );
        await prisma.user.update({
          where: { id: created.user!.id },
          data: { googleId: profile.googleId },
        });
        return {
          user: created.user,
          accessToken: created.accessToken,
          refreshToken: created.refreshToken,
          needsPinSetup: true as const,
        };
      }
    }

    if (!user.isActive) return { error: 'account_disabled' as const };

    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    const safeUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: safeUserSelect,
    });
    return {
      user: safeUser,
      accessToken,
      refreshToken,
      needsPinSetup: !user.recoveryPinHash,
    };
  }

  /** Set (or replace) the recovery PIN — called right after Google signup,
   * or any time after from Settings. Requires an active session; there's
   * no separate "confirm current PIN" step since this is the same trust
   * level as the session that's already authenticated. */
  async setRecoveryPin(userId: number, pin: string) {
    const recoveryPinHash = await bcrypt.hash(pin, 12);
    await prisma.user.update({
      where: { id: userId },
      data: { recoveryPinHash, recoveryPinSetAt: new Date() },
    });
    return { ok: true as const };
  }

  /** Fallback sign-in for Google-only accounts when Google itself isn't
   * reachable. Shares the same per-account throttle as password login
   * (loginThrottle.ts) — one brute-force guard per account regardless of
   * which credential the attacker is trying. */
  async loginWithRecoveryPin(email: string, pin: string, totpCode?: string, device?: DeviceContext) {
    const normEmail = email.toLowerCase().trim();

    const lockedMs = await loginLockRemainingMs(normEmail);
    if (lockedMs > 0) return { error: 'locked' as const, retryAfterMs: lockedMs };

    const user = await prisma.user.findUnique({ where: { email: normEmail } });
    const dummyHash = '$2b$12$invalidhashpadding000000000000000000000000000000000000';
    const valid = user?.recoveryPinHash
      ? await bcrypt.compare(pin, user.recoveryPinHash)
      : await bcrypt.compare(pin, dummyHash).then(() => false);

    if (!user || !user.isActive || !valid) {
      await recordLoginFailure(normEmail);
      return { error: 'Invalid email or recovery PIN' as const };
    }

    if (user.totpEnabledAt) {
      if (!totpCode) return { error: '2fa_required' as const };
      const okTotp = await totpService.verifyForLogin(user.id, totpCode);
      if (!okTotp) {
        await recordLoginFailure(normEmail);
        return { error: '2fa_invalid' as const };
      }
    }

    await clearLoginFailures(normEmail);
    const { accessToken, refreshToken } = await issueSession(user, undefined, device);
    const safeUser = await prisma.user.findUnique({
      where: { id: user.id },
      select: safeUserSelect,
    });
    return { user: safeUser, accessToken, refreshToken };
  }

  async refresh(token: string, device?: DeviceContext) {
    let payload: { sub: number; family?: string };
    try {
      // Pin the algorithm (AUTH-2): without `algorithms`, jsonwebtoken accepts
      // any alg the token header claims. Refresh tokens are minted HS256
      // (see signRefresh), so verification must only ever accept HS256 — never
      // trust an attacker-chosen header alg.
      payload = jwt.verify(token, REFRESH_SECRET, { algorithms: ['HS256'] }) as unknown as {
        sub: number;
        family?: string;
      };
    } catch {
      return { error: 'Invalid refresh token' as const };
    }

    const tokenHash = hashToken(token);
    const stored = await prisma.refreshToken.findUnique({ where: { token: tokenHash } });
    if (!stored) {
      // The JWT verified (valid signature, unexpired) but its hash isn't
      // stored — it was already rotated away or logged out. If its family
      // still has live members, this is a replay of a rotated token, so
      // revoke the entire family and force a fresh login (B-AUTH-2).
      if (payload.family) {
        const familyAlive = await prisma.refreshToken.findFirst({
          where: { family: payload.family },
          select: { id: true },
        });
        if (familyAlive) {
          await prisma.refreshToken.deleteMany({ where: { family: payload.family } });
        }
      }
      return { error: 'Refresh token expired or revoked' as const };
    }
    if (stored.expiresAt < new Date()) {
      await prisma.refreshToken.delete({ where: { id: stored.id } });
      return { error: 'Refresh token expired or revoked' as const };
    }

    const user = await prisma.user.findUnique({
      where: { id: payload.sub },
      select: { id: true, email: true, role: true, isPlatformAdmin: true, isActive: true },
    });
    if (!user || !user.isActive) {
      await prisma.refreshToken.delete({ where: { id: stored.id } });
      return { error: 'Account not found or deactivated' as const };
    }

    // Rotate within the same family: delete old token, issue new pair.
    await prisma.refreshToken.delete({ where: { id: stored.id } });
    const { accessToken, refreshToken } = await issueSession(user, stored.family, device);
    return { accessToken, refreshToken };
  }

  async logout(token: string) {
    // Drop the refresh token AND revoke its session id so the paired access
    // token stops working immediately, not just at its 15-min TTL. Look the
    // row up first (indexed unique) to learn the family = session id.
    const stored = await prisma.refreshToken.findUnique({
      where: { token: hashToken(token) },
      select: { id: true, family: true },
    });
    if (!stored) return;
    await prisma.refreshToken.delete({ where: { id: stored.id } });
    await revokeSession(stored.family);
  }

  /// Revoke every refresh token for this user — drops other-device
  /// sessions in one shot — AND bumps `tokensValidFrom` so every
  /// outstanding access token also rejects at next requireAuth (closes
  /// the 15-minute TTL window that would otherwise let a stolen access
  /// token survive logout-all).
  async logoutAll(userId: number) {
    const stamp = new Date();
    await prisma.$transaction([
      prisma.refreshToken.deleteMany({ where: { userId } }),
      // "Sign out everywhere" also forgets every remembered device — the
      // whole point is to cut off all access, not just active sessions.
      prisma.rememberToken.deleteMany({ where: { userId } }),
      prisma.user.update({
        where: { id: userId },
        data: { tokensValidFrom: stamp },
      }),
    ]);
    bumpTokensValidFromCache(userId, stamp);
  }

  /// Issue a device-remember credential for a returning one-tap sign-in on a
  /// trusted native app (desktop / Flutter merchant). The raw secret is
  /// returned ONCE and must be stored only in the device OS keychain; we keep
  /// its hash. Old tokens beyond the per-user cap are pruned (FIFO).
  async issueRememberToken(userId: number, label?: string | null) {
    const raw = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + REMEMBER_EXPIRES_MS);
    await prisma.rememberToken.create({
      data: { userId, tokenHash: hashToken(raw), label: label?.slice(0, 80) ?? null, expiresAt },
    });
    const active = await prisma.rememberToken.findMany({
      where: { userId },
      orderBy: { createdAt: 'asc' },
      select: { id: true },
    });
    if (active.length > MAX_REMEMBER_TOKENS_PER_USER) {
      const excess = active.slice(0, active.length - MAX_REMEMBER_TOKENS_PER_USER);
      await prisma.rememberToken.deleteMany({ where: { id: { in: excess.map((t) => t.id) } } });
    }
    return { rememberToken: raw, expiresAt };
  }

  /// Exchange a device-remember credential for a fresh session — no password.
  /// Rotates the credential (single-use) and mints a new access+refresh pair.
  /// A bad/expired token, or a deactivated account, is rejected and cleaned up.
  async rememberLogin(raw: string, device?: DeviceContext) {
    const stored = await prisma.rememberToken.findUnique({
      where: { tokenHash: hashToken(raw) },
      select: { id: true, userId: true, label: true, expiresAt: true },
    });
    if (!stored) return { error: 'This saved sign-in is no longer valid' as const };
    if (stored.expiresAt < new Date()) {
      await prisma.rememberToken.delete({ where: { id: stored.id } });
      return { error: 'This saved sign-in has expired' as const };
    }
    const user = await prisma.user.findUnique({
      where: { id: stored.userId },
      select: { ...safeUserSelect, isActive: true },
    });
    if (!user || !user.isActive) {
      await prisma.rememberToken.delete({ where: { id: stored.id } });
      return { error: 'This account is no longer available' as const };
    }

    // Rotate the remember credential (single-use) and mint a fresh session.
    const newRaw = crypto.randomBytes(32).toString('hex');
    const rememberExpiresAt = new Date(Date.now() + REMEMBER_EXPIRES_MS);
    await prisma.$transaction([
      prisma.rememberToken.delete({ where: { id: stored.id } }),
      prisma.rememberToken.create({
        data: { userId: user.id, tokenHash: hashToken(newRaw), label: stored.label, expiresAt: rememberExpiresAt },
      }),
    ]);
    const { isActive: _isActive, ...safeUser } = user;
    const { accessToken, refreshToken } = await issueSession(safeUser, undefined, device);
    return { user: safeUser, accessToken, refreshToken, rememberToken: newRaw, rememberExpiresAt };
  }

  /// Forget a single remembered device ("Remove this account" on the picker).
  /// Idempotent — an already-gone token is a no-op.
  async forgetRememberToken(raw: string) {
    await prisma.rememberToken.deleteMany({ where: { tokenHash: hashToken(raw) } });
  }

  getMe(userId: number) {
    return prisma.user.findUnique({ where: { id: userId }, select: safeUserSelect });
  }

  async updateProfile(
    userId: number,
    data: {
      name?: string;
      emailNotifications?: boolean;
      // Shop profile fields — used to populate the invoice header /
      // GST footer / UPI QR. All independently optional so the settings
      // screen can PATCH a single field at a time.
      shopName?: string | null;
      shopAddress?: string | null;
      shopCity?: string | null;
      shopState?: string | null;
      shopStateCode?: string | null;
      shopPinCode?: string | null;
      shopGstin?: string | null;
      // Calendar date GST starts applying — see gstEffectiveFrom on the
      // Prisma User model. YYYY-MM-DD or null; the guard below requires it
      // the moment a shop newly registers for GST.
      gstEffectiveFrom?: string | null;
      registrationType?: 'REGULAR' | 'COMPOSITION' | 'UNREGISTERED';
      shopPan?: string | null;
      upiVpa?: string | null;
      // Profile photo URL (upload-service path). Editable from both
      // the customer Edit Profile page and the merchant Settings page.
      avatarUrl?: string | null;
      // E.164-format phone, surfaced on customer Edit Profile.
      phoneNumber?: string | null;
      // Granular notification preferences (Phase 5).
      notifyOrders?: boolean;
      notifyDeals?: boolean;
      notifyAccount?: boolean;
      notifyMessages?: boolean;
      pushEnabled?: boolean;
      smsEnabled?: boolean;
    },
  ) {
    const updates: {
      name?: string;
      emailNotifications?: boolean;
      shopName?: string | null;
      shopAddress?: string | null;
      shopCity?: string | null;
      shopState?: string | null;
      shopStateCode?: string | null;
      shopPinCode?: string | null;
      shopGstin?: string | null;
      gstEffectiveFrom?: Date | null;
      registrationType?: 'REGULAR' | 'COMPOSITION' | 'UNREGISTERED';
      shopPan?: string | null;
      upiVpa?: string | null;
      avatarUrl?: string | null;
      phoneNumber?: string | null;
      notifyOrders?: boolean;
      notifyDeals?: boolean;
      notifyAccount?: boolean;
      notifyMessages?: boolean;
      pushEnabled?: boolean;
      smsEnabled?: boolean;
    } = {};
    if (data.name !== undefined) updates.name = data.name;
    if (data.emailNotifications !== undefined) {
      updates.emailNotifications = data.emailNotifications;
    }
    if (data.shopName !== undefined) updates.shopName = data.shopName;
    if (data.shopAddress !== undefined) updates.shopAddress = data.shopAddress;
    if (data.shopCity !== undefined) updates.shopCity = data.shopCity;
    if (data.shopState !== undefined) updates.shopState = data.shopState;
    if (data.shopStateCode !== undefined) updates.shopStateCode = data.shopStateCode;
    if (data.shopPinCode !== undefined) updates.shopPinCode = data.shopPinCode;
    if (data.shopGstin !== undefined) updates.shopGstin = data.shopGstin;
    // Keep registration status coherent with the GSTIN. An explicit value
    // always wins (so a composition dealer can mark themselves COMPOSITION);
    // otherwise a GSTIN ⇒ REGULAR and a cleared GSTIN ⇒ UNREGISTERED.
    if (data.registrationType !== undefined) {
      updates.registrationType = data.registrationType;
    } else if (data.shopGstin !== undefined) {
      updates.registrationType = data.shopGstin ? 'REGULAR' : 'UNREGISTERED';
    }
    if (data.gstEffectiveFrom !== undefined) {
      updates.gstEffectiveFrom = data.gstEffectiveFrom
        ? new Date(`${data.gstEffectiveFrom}T00:00:00.000Z`)
        : null;
    }
    if (data.shopPan !== undefined) updates.shopPan = data.shopPan;
    if (data.upiVpa !== undefined) updates.upiVpa = data.upiVpa;
    if (data.avatarUrl !== undefined) updates.avatarUrl = data.avatarUrl;
    if (data.phoneNumber !== undefined) updates.phoneNumber = data.phoneNumber;
    if (data.notifyOrders !== undefined) updates.notifyOrders = data.notifyOrders;
    if (data.notifyDeals !== undefined) updates.notifyDeals = data.notifyDeals;
    if (data.notifyAccount !== undefined) updates.notifyAccount = data.notifyAccount;
    if (data.notifyMessages !== undefined) updates.notifyMessages = data.notifyMessages;
    if (data.pushEnabled !== undefined) updates.pushEnabled = data.pushEnabled;
    if (data.smsEnabled !== undefined) updates.smsEnabled = data.smsEnabled;
    if (Object.keys(updates).length === 0) {
      return prisma.user.findUnique({ where: { id: userId }, select: safeUserSelect });
    }

    // GST-effective-date guard: force the precise "from when" decision only
    // at the exact moment a shop is newly acquiring/changing its GSTIN and
    // resolves to REGULAR. Only query the current row when shopGstin is
    // actually part of this request — the overwhelming majority of profile
    // edits never touch this and skip the extra query entirely.
    if (data.shopGstin !== undefined) {
      const current = await prisma.user.findUnique({
        where: { id: userId },
        select: { shopGstin: true, gstEffectiveFrom: true },
      });
      if (!current) return null;
      const isNewGstinRegistration =
        data.shopGstin !== null && data.shopGstin !== current.shopGstin;
      if (isNewGstinRegistration && updates.registrationType === 'REGULAR') {
        const resolvedEffectiveFrom =
          data.gstEffectiveFrom !== undefined
            ? updates.gstEffectiveFrom
            : current.gstEffectiveFrom;
        if (resolvedEffectiveFrom == null) {
          return { error: 'GST_EFFECTIVE_DATE_REQUIRED' as const };
        }
      }
    }

    return prisma.user.update({
      where: { id: userId },
      data: updates,
      select: safeUserSelect,
    });
  }

  async changePassword(userId: number, currentPassword: string, newPassword: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { error: 'User not found' as const };

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) return { error: 'Current password is incorrect' as const };
    if (await isPasswordBreached(newPassword)) {
      return { error: 'password_breached' as const };
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const stamp = new Date();
    // Atomic: password rewrite + sessions revoked + tokensValidFrom
    // bumped so a stolen access token (issued before the change) is
    // rejected by requireAuth even within its 15-minute TTL.
    await prisma.$transaction([
      prisma.user.update({
        where: { id: userId },
        data: { passwordHash, tokensValidFrom: stamp },
      }),
      prisma.refreshToken.deleteMany({ where: { userId } }),
      // A new password invalidates every remembered device too.
      prisma.rememberToken.deleteMany({ where: { userId } }),
    ]);
    bumpTokensValidFromCache(userId, stamp);

    // Best-effort security alert. If the notification write fails we still
    // consider the password change successful — the user has already been
    // logged out everywhere via the refresh-token sweep above.
    try {
      await notificationsService.create({
        userId,
        kind: 'SECURITY',
        title: 'Password changed',
        body: "Your password was changed. If this wasn't you, contact support.",
      });
    } catch (err) {
      logger.warn({ event: 'password_change_notification_failed', userId, err }, 'Failed to write password-change notification');
    }

    return { ok: true };
  }

  /**
   * Start a password reset: email a 6-digit code.
   *
   * **Always reports success**, whether or not the address belongs to an
   * account. Saying "no such user" here would turn this endpoint into a free
   * account-enumeration oracle — anyone could test an email list against it.
   * The caller therefore learns nothing; only a real mailbox owner sees the
   * difference, which is the point.
   *
   * Silently no-ops (still reporting success) when the address is unknown,
   * when a code was already sent inside the cooldown, or when the mail/Redis
   * infra is down. Each case is logged so the absence of a code is
   * diagnosable from the server side.
   */
  async requestPasswordReset(email: string) {
    const norm = email.toLowerCase().trim();

    if (!canVerifyEmail()) {
      logger.error(
        { event: 'pwreset_unavailable', redis: redisAvailable(), mailer: mailerEnabled() },
        'Password reset requested but the OTP infra is unavailable',
      );
      return { ok: true as const };
    }

    const user = await prisma.user.findUnique({
      where: { email: norm },
      select: { id: true, name: true, isActive: true },
    });
    if (!user || !user.isActive) {
      logger.info({ event: 'pwreset_unknown_email' }, 'Password reset for an unknown/inactive address');
      return { ok: true as const };
    }

    // Rate-limit: one code per cooldown window, so this can't be used to
    // mail-bomb someone whose address an attacker happens to know.
    if ((await resetCooldownRemaining(norm)) > 0) {
      logger.info({ event: 'pwreset_cooldown', userId: user.id }, 'Password reset suppressed by cooldown');
      return { ok: true as const };
    }

    const otp = generateOtp();
    if (!(await sendResetOtpEmail(norm, user.name, otp))) {
      logger.error({ event: 'pwreset_send_failed', userId: user.id }, 'Password reset email failed to send');
      return { ok: true as const };
    }
    await putPendingReset(norm, otp);
    await markResetSent(norm);
    return { ok: true as const };
  }

  /**
   * Finish a password reset: confirm the code, rewrite the password, and log
   * every session out.
   *
   * The sweep is the whole point of a reset rather than a change — whoever
   * prompted it may be locked out precisely because someone else is holding a
   * live session. Mirrors `changePassword`'s transaction exactly (password +
   * `tokensValidFrom` + refresh tokens + remembered devices), so an access
   * token minted seconds ago is rejected inside its 15-minute TTL too.
   *
   * No session is issued here. The user signs in with the new password, which
   * keeps this unauthenticated endpoint incapable of handing out credentials.
   */
  async resetPassword(email: string, otp: string, newPassword: string) {
    const norm = email.toLowerCase().trim();

    const check = await verifyResetOtp(norm, otp);
    if (!check.ok) return { error: check.reason };

    const user = await prisma.user.findUnique({
      where: { email: norm },
      select: { id: true, isActive: true },
    });
    // The account vanished (or was deactivated) between request and reset.
    if (!user || !user.isActive) {
      await dropPendingReset(norm);
      return { error: 'expired' as const };
    }

    if (await isPasswordBreached(newPassword)) {
      // Deliberately NOT dropping the pending code: the code was correct and
      // the only problem is the chosen password. Burning it here would force
      // a whole new email for a typo-grade mistake.
      return { error: 'password_breached' as const };
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    const stamp = new Date();
    await prisma.$transaction([
      prisma.user.update({
        where: { id: user.id },
        data: { passwordHash, tokensValidFrom: stamp },
      }),
      prisma.refreshToken.deleteMany({ where: { userId: user.id } }),
      prisma.rememberToken.deleteMany({ where: { userId: user.id } }),
    ]);
    bumpTokensValidFromCache(user.id, stamp);
    // Only now is the code spent — see `verifyResetOtp`.
    await dropPendingReset(norm);

    try {
      await notificationsService.create({
        userId: user.id,
        kind: 'SECURITY',
        title: 'Password reset',
        body: "Your password was reset and every device was signed out. If this wasn't you, contact support immediately.",
      });
    } catch (err) {
      logger.warn(
        { event: 'pwreset_notification_failed', userId: user.id, err },
        'Failed to write password-reset notification',
      );
    }

    return { ok: true as const };
  }

  /// DPDP §11 right-to-access: build a single JSON blob containing
  /// every row this user can reasonably claim as "their data". Shape
  /// depends on role — OWNERs get a full shop dump (so they can take
  /// their books elsewhere), CUSTOMERs get only their own activity.
  /// Refresh tokens are deliberately summarised to a count to avoid
  /// handing out live session secrets.
  async exportData(userId: number): Promise<Record<string, unknown>> {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      include: {
        notifications: true,
        invitationsSent: {
          include: {
            toUser: { select: { email: true, name: true } },
          },
        },
        invitationsReceived: {
          include: {
            fromUser: { select: { email: true, name: true } },
          },
        },
        linkedParties: { select: { id: true, name: true } },
        linkedVendors: { select: { id: true, name: true } },
        purchaseRequests: { include: { items: true } },
        // DPDP §11 right-to-access: these are unambiguously the data
        // principal's own personal data and must appear in the export.
        // All are user-scoped relations on User (no cross-tenant leak).
        addresses: true,
        productReviews: true,
        wishlistItems: { include: { product: { select: { id: true, name: true } } } },
        cartItems: { include: { product: { select: { id: true, name: true } } } },
        customerOrders: { include: { shopOrders: { include: { items: true } } } },
        returnsRequested: { include: { items: true } },
      },
    });
    if (!user) return { error: 'user_not_found' };

    const refreshTokenCount = await prisma.refreshToken.count({
      where: { userId },
    });

    // Strip the password hash before serialising — never include
    // credential material in an export, even one going to the owner.
    const { passwordHash: _ph, ...safeUser } = user;

    const blob: Record<string, unknown> = {
      exportedAt: new Date().toISOString(),
      user: safeUser,
      refreshTokenCount,
      notifications: user.notifications,
      invitationsSent: user.invitationsSent,
      invitationsReceived: user.invitationsReceived,
      linkedParties: user.linkedParties,
      linkedVendors: user.linkedVendors,
      purchaseRequests: user.purchaseRequests,
      // DPDP §11 — the customer's own activity. Present for every role;
      // an OWNER who never shopped simply gets empty arrays.
      addresses: user.addresses,
      productReviews: user.productReviews,
      wishlistItems: user.wishlistItems,
      cartItems: user.cartItems,
      customerOrders: user.customerOrders,
      returnRequests: user.returnsRequested,
    };

    if (user.role === 'OWNER') {
      // Full shop dump — owners are the data fiduciary for THEIR shop's
      // rows. Every findMany MUST be scoped by shopId; without that
      // scoping, one merchant's export returns every other merchant's
      // data (DPDP/multi-tenant breach).
      const ownedShop = await prisma.shop.findUnique({
        where: { ownerUserId: userId },
        select: { id: true },
      });
      const shopId = ownedShop?.id;
      if (shopId !== undefined) {
        const [
          products,
          categories,
          parties,
          vendors,
          invoices,
          payments,
          challans,
          customFieldDefinitions,
          customFieldSections,
          stockTransactions,
          stockAdjustments,
        ] = await Promise.all([
          prisma.product.findMany({
            where: { shopId },
            include: { images: true, customFieldValues: true },
          }),
          // Categories are a global taxonomy shared across shops; not
          // scoped by shopId, so we return the full list as reference
          // data (not per-tenant content).
          prisma.category.findMany(),
          prisma.party.findMany({ where: { shopId } }),
          prisma.vendor.findMany({ where: { shopId } }),
          prisma.invoice.findMany({
            where: { shopId },
            include: { items: true },
          }),
          prisma.payment.findMany({ where: { shopId } }),
          prisma.challan.findMany({
            where: { shopId },
            include: { items: true },
          }),
          prisma.customFieldDefinition.findMany({ where: { shopId } }),
          prisma.customFieldSection.findMany({ where: { shopId } }),
          prisma.stockTransaction.findMany({ where: { shopId } }),
          prisma.stockAdjustment.findMany({
            where: { shopId },
            include: { items: true },
          }),
        ]);
        blob.shop = {
          shopId,
          products,
          categories,
          parties,
          vendors,
          invoices,
          payments,
          challans,
          customFieldDefinitions,
          customFieldSections,
          stockTransactions,
          stockAdjustments,
        };
      }
    }

    return blob;
  }

  /// DPDP §12 right-to-erasure. OWNER accounts that still hold legally
  /// retained records (CONFIRMED invoices within the 8-year Companies
  /// Act window) can NOT be hard-deleted — but the DPDP right is still
  /// honoured via a *controlled wipe*: we hard-delete all non-retained
  /// PII (notifications, addresses, wishlist/cart, sessions) and
  /// pseudonymise the user identity that the retained invoices reference
  /// (name/email/phone/avatar replaced with a tombstone), keeping only
  /// the statutory invoice rows. CUSTOMER accounts (and OWNERs with no
  /// retained records) cascade-delete freely because the schema's
  /// onDelete rules cover their footprint.
  async deleteAccount(userId: number, currentPassword: string) {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    if (!user) return { error: 'user_not_found' as const };

    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) return { error: 'invalid_password' as const };

    if (user.role === 'OWNER') {
      // A hard delete of the User cascades to their Shop (Shop.ownerUserId is
      // onDelete: Cascade). That cascade is unsafe for a shop with any data:
      //   1. Product.shop is onDelete: Restrict, so the cascade hits a foreign-
      //      key violation and the whole delete fails (the bug this fixes).
      //   2. Invoice.shop is onDelete: Cascade, so it would silently erase
      //      invoices that are statutory books of account (Companies Act §128 +
      //      GST §36 — 8 financial years).
      // So whenever the owner's shop holds ANY business records, we keep the
      // records and pseudonymise the identity instead of hard-deleting. The
      // check is scoped to this user's own shop. Only a genuinely empty shop
      // (no products, no invoices) is safe to let the cascade remove.
      const ownedShop = await prisma.shop.findUnique({
        where: { ownerUserId: userId },
        select: { id: true },
      });
      if (ownedShop) {
        const [productCount, invoiceCount] = await Promise.all([
          prisma.product.count({ where: { shopId: ownedShop.id } }),
          prisma.invoice.count({ where: { shopId: ownedShop.id } }),
        ]);
        if (productCount > 0 || invoiceCount > 0) {
          // PII-4 — can't safely hard-delete, so pseudonymise.
          return this.pseudonymiseAccount(userId);
        }
      }
    }

    await prisma.$transaction(async (tx) => {
      // DPDP §12 erasure must be complete AND consistent. ProductReview.user
      // is onDelete: Cascade, so `user.delete` removes this customer's reviews
      // at the DB level — which bypasses recomputeRatingDenorm and leaves
      // Product.ratingAvg/ratingCount (and Shop.rating denorm) inflated/stale
      // forever (CP E-Commerce Rules: no misleading ratings). So: capture the
      // affected productIds first, delete the reviews via this tx, then
      // recompute each product's denorm in the same transaction.
      const reviewedProducts = await tx.productReview.findMany({
        where: { userId },
        select: { productId: true },
        distinct: ['productId'],
      });
      const affectedProductIds = reviewedProducts.map((r) => r.productId);
      if (affectedProductIds.length > 0) {
        await tx.productReview.deleteMany({ where: { userId } });
        for (const productId of affectedProductIds) {
          const agg = await tx.productReview.aggregate({
            where: { productId },
            _avg: { rating: true },
            _count: { _all: true },
          });
          await tx.product.update({
            where: { id: productId },
            data: {
              ratingAvg: agg._avg.rating,
              ratingCount: agg._count._all,
            },
          });
        }
      }

      // Cascade should handle refresh tokens but be explicit — keeps
      // the intent obvious and survives any future onDelete change.
      await tx.refreshToken.deleteMany({ where: { userId } });
      await tx.user.delete({ where: { id: userId } });
    });

    return { ok: true as const, mode: 'deleted' as const };
  }

  /// PII-4 controlled wipe for OWNERs whose CONFIRMED invoices are still
  /// inside the 8-year statutory retention window. We CANNOT delete the
  /// User row — invoices and the owned Shop reference it and must be kept
  /// for tax/company law — so we hard-delete the non-retained PII and
  /// overwrite the identity fields with a tombstone. The account is left
  /// deactivated (isActive = false) and login is blocked: the email is
  /// rotated to an unusable address, the password hash is scrambled, and
  /// tokensValidFrom is bumped so any live access token is rejected.
  private async pseudonymiseAccount(userId: number) {
    await prisma.$transaction(async (tx) => {
      // Reviews still need the rating denorm reconciled (same reasoning as
      // the hard-delete path): drop this user's reviews, then recompute.
      const reviewedProducts = await tx.productReview.findMany({
        where: { userId },
        select: { productId: true },
        distinct: ['productId'],
      });
      const affectedProductIds = reviewedProducts.map((r) => r.productId);
      if (affectedProductIds.length > 0) {
        await tx.productReview.deleteMany({ where: { userId } });
        for (const productId of affectedProductIds) {
          const agg = await tx.productReview.aggregate({
            where: { productId },
            _avg: { rating: true },
            _count: { _all: true },
          });
          await tx.product.update({
            where: { id: productId },
            data: {
              ratingAvg: agg._avg.rating,
              ratingCount: agg._count._all,
            },
          });
        }
      }

      // Hard-delete the non-retained PII footprint. None of these are
      // books-of-account; they carry no statutory retention obligation.
      await tx.notification.deleteMany({ where: { userId } });
      await tx.userAddress.deleteMany({ where: { userId } });
      await tx.wishlistItem.deleteMany({ where: { userId } });
      await tx.cartItem.deleteMany({ where: { userId } });
      await tx.refreshToken.deleteMany({ where: { userId } });
      await tx.rememberToken.deleteMany({ where: { userId } });

      // Pseudonymise the identity referenced by the retained invoices.
      // Email is @unique, so the tombstone must be unique per user. The
      // scrambled password hash + bumped tokensValidFrom make the account
      // permanently unusable for login while keeping the row intact.
      await tx.user.update({
        where: { id: userId },
        data: {
          name: 'Deleted user',
          email: `deleted+${userId}@deleted.shopxy.invalid`,
          passwordHash: await bcrypt.hash(crypto.randomUUID(), 12),
          phoneNumber: null,
          avatarUrl: null,
          isActive: false,
          tokensValidFrom: new Date(),
          // Silence any future dispatch; the principal is gone.
          emailNotifications: false,
          notifyOrders: false,
          notifyDeals: false,
          notifyAccount: false,
          notifyMessages: false,
          pushEnabled: false,
          smsEnabled: false,
        },
      });
    });

    return { ok: true as const, mode: 'pseudonymised' as const };
  }
}

export const authService = new AuthService();
