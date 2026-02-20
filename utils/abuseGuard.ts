import { createHash } from 'crypto';

declare function countUserAnalyzesToday(userId: string): Promise<number>;
declare function isIpRateLimited(ip: string, limitPerMinute: number): Promise<boolean>;
declare function hasDuplicatePdf(userId: string, pdfHash: string): Promise<boolean>;

export async function abuseGuard(params: {
  userId: string;
  ipAddress: string;
  pdfBuffer: Buffer;
}): Promise<void> {
  if (await isIpRateLimited(params.ipAddress, 2)) {
    throw new Error('RATE_LIMITED');
  }

  if ((await countUserAnalyzesToday(params.userId)) >= 5) {
    throw new Error('DAILY_CAP');
  }

  const hash = createHash('sha256').update(params.pdfBuffer).digest('hex');

  if (await hasDuplicatePdf(params.userId, hash)) {
    throw new Error('DUPLICATE_PDF');
  }
}
