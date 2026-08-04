import type { MailComposeDraft, MailMessage } from '@/types/mail'

export const MAIL_DOMAIN = 'ifruit.com'
export const MAIL_MAX_RECIPIENTS = 10

export function normalizeMailAddress(value: string): string | null {
  const normalized = value.trim().toLocaleLowerCase('en-US')
  const localPart = normalized.includes('@')
    ? normalized.endsWith(`@${MAIL_DOMAIN}`)
      ? normalized.slice(0, -MAIL_DOMAIN.length - 1)
      : ''
    : normalized

  if (
    localPart.length < 3 ||
    localPart.length > 32 ||
    !/^[a-z0-9][a-z0-9._-]*[a-z0-9]$/.test(localPart) ||
    localPart.includes('..')
  ) {
    return null
  }

  return `${localPart}@${MAIL_DOMAIN}`
}

export function parseMailRecipients(value: string): string[] | null {
  const parts = value
    .split(/[;,]/)
    .map((part) => part.trim())
    .filter(Boolean)
  if (!parts.length || parts.length > MAIL_MAX_RECIPIENTS) return null

  const recipients: string[] = []
  const seen = new Set<string>()
  for (const part of parts) {
    const email = normalizeMailAddress(part)
    if (!email) return null
    if (!seen.has(email)) {
      seen.add(email)
      recipients.push(email)
    }
  }
  return recipients
}

function prefixedSubject(prefix: 'Re' | 'Fwd', subject: string): string {
  const clean = subject.trim()
  if (new RegExp(`^${prefix}:`, 'i').test(clean)) return clean
  return `${prefix}: ${clean || '(no subject)'}`
}

export function buildReplyDraft(
  message: MailMessage,
  ownEmail: string,
  replyAll = false,
): MailComposeDraft {
  const candidates = replyAll
    ? [message.sender, ...message.recipients]
    : [message.sender]
  const recipients = [...new Set(candidates)].filter(
    (address) => address !== ownEmail,
  )

  return {
    body: `\n--- ${message.sender} ---\n${message.body}`,
    recipients,
    subject: prefixedSubject('Re', message.subject),
  }
}

export function buildForwardDraft(message: MailMessage): MailComposeDraft {
  return {
    body: `\n--- Forwarded message ---\nFrom: ${message.sender}\nTo: ${message.recipients.join(', ')}\n\n${message.body}`,
    recipients: [],
    subject: prefixedSubject('Fwd', message.subject),
  }
}
