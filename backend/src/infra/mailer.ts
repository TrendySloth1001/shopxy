import nodemailer, { type Transporter } from 'nodemailer';
import { envOr, envBool } from '../shared/env.js';
import { logger } from '../shared/logging/logger.js';

const gmUser = process.env.GMAIL_USER;
const gmClientId = process.env.GMAIL_CLIENT_ID;
const gmClientSecret = process.env.GMAIL_CLIENT_SECRET;
const gmRefreshToken = process.env.GMAIL_REFRESH_TOKEN;

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

const from = gmailConfigured()
  ? (gmUser as string)
  : envOr('SMTP_FROM', smtpUser ?? 'no-reply@shopxy.app');

let transporter: Transporter | null = null;

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
      secure: smtpPort === 465,
      auth: { user: smtpUser, pass: smtpPass },
    });
  }
  return transporter;
}

export type MailCategory = 'otp' | 'notification';

export interface Mail {
  to: string;
  subject: string;
  text: string;
  html?: string;
  category?: MailCategory;
}

export function notificationsEnabled(): boolean {
  return envBool('MAIL_NOTIFICATIONS_ENABLED', false);
}

export async function sendMail(mail: Mail): Promise<boolean> {
  const category: MailCategory = mail.category ?? 'notification';
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
