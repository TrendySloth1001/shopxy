import nodemailer, { type Transporter } from 'nodemailer';
import { envOr, envBool } from '../shared/env.js';
import { logger } from '../shared/logging/logger.js';

/**
 * Single source of truth for outbound email.
 *
 * Two providers, chosen by which env vars are present (no code change to
 * switch):
 *
 * 1. **Gmail OAuth2** — set `GMAIL_USER`, `GMAIL_CLIENT_ID`,
 *    `GMAIL_CLIENT_SECRET`, `GMAIL_REFRESH_TOKEN` (from Google Cloud). Sends
 *    directly as the Gmail address; nodemailer refreshes access tokens itself.
 * 2. **Generic SMTP** — set `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS`
 *    (Gmail App Password, Brevo, SES, …), optional `SMTP_FROM`.
 *
 * OAuth2 wins if configured. Mirrors the Redis "graceful degradation" stance:
 * if nothing is configured (or a send fails) we log and move on — email is a
 * best-effort side channel, never on a request's critical path.
 */

// ── Gmail OAuth2 config ──
const gmUser = process.env.GMAIL_USER;
const gmClientId = process.env.GMAIL_CLIENT_ID;
const gmClientSecret = process.env.GMAIL_CLIENT_SECRET;
const gmRefreshToken = process.env.GMAIL_REFRESH_TOKEN;

// ── Generic SMTP config ──
const smtpHost = process.env.SMTP_HOST;
const smtpUser = process.env.SMTP_USER;
const smtpPass = process.env.SMTP_PASS;
const smtpPort = Number(process.env.SMTP_PORT ?? 587);

function gmailConfigured(): boolean {
  return !!(gmUser && gmClientId && gmClientSecret && gmRefreshToken);
}
function smtpConfigured(): boolean {
  return !!(smtpHost && smtpUser && smtpPass);
}

/** The address mail is sent from — the Gmail user, or SMTP_FROM/SMTP_USER. */
const from = gmailConfigured()
  ? (gmUser as string)
  : envOr('SMTP_FROM', smtpUser ?? 'no-reply@shopxy.app');

let transporter: Transporter | null = null;

/** True when a provider is configured well enough to attempt a send. */
export function mailerEnabled(): boolean {
  return gmailConfigured() || smtpConfigured();
}

function getTransport(): Transporter | null {
  if (transporter) return transporter;
  if (gmailConfigured()) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        type: 'OAuth2',
        user: gmUser,
        clientId: gmClientId,
        clientSecret: gmClientSecret,
        refreshToken: gmRefreshToken,
      },
    });
  } else if (smtpConfigured()) {
    transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure: smtpPort === 465, // 465 = implicit TLS; 587 = STARTTLS
      auth: { user: smtpUser, pass: smtpPass },
    });
  }
  return transporter;
}

/**
 * Which class of mail this is. Only `otp` is sent by default; every other
 * category (login alerts, and any future transactional/marketing mail) is
 * suppressed unless `MAIL_NOTIFICATIONS_ENABLED` is switched on. Callers that
 * don't set it are treated as `notification` — i.e. off by default. This keeps
 * the deliverability/spam surface to the one email users must receive to sign
 * up, while the rest can be enabled later once a proper sending domain is set.
 */
export type MailCategory = 'otp' | 'notification';

export interface Mail {
  to: string;
  subject: string;
  text: string;
  html?: string;
  /** Defaults to `notification` (off by default). Set `otp` for signup codes. */
  category?: MailCategory;
}

/** True when non-OTP mail (login alerts, etc.) is explicitly enabled. */
export function notificationsEnabled(): boolean {
  return envBool('MAIL_NOTIFICATIONS_ENABLED', false);
}

/** Best-effort send. Returns true when handed to the mail server. Never throws. */
export async function sendMail(mail: Mail): Promise<boolean> {
  const category: MailCategory = mail.category ?? 'notification';
  // Default posture: OTP only. All other mail stays off until a sending
  // domain is configured and MAIL_NOTIFICATIONS_ENABLED is turned on.
  if (category !== 'otp' && !notificationsEnabled()) {
    logger.debug(
      { to: mail.to, subject: mail.subject },
      'mailer: non-OTP mail suppressed (MAIL_NOTIFICATIONS_ENABLED off)',
    );
    return false;
  }
  const t = getTransport();
  if (!t) {
    logger.warn('mailer: no provider configured — skipping send');
    return false;
  }
  try {
    await t.sendMail({ from, to: mail.to, subject: mail.subject, text: mail.text, html: mail.html });
    return true;
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'mailer: send failed');
    return false;
  }
}

/** Verify connectivity/credentials without sending — used by the dev check. */
export async function verifyMailer(): Promise<boolean> {
  const t = getTransport();
  if (!t) return false;
  try {
    await t.verify();
    return true;
  } catch (err) {
    logger.warn({ err: (err as Error).message }, 'mailer: verify failed');
    return false;
  }
}
