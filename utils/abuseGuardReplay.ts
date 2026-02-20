import { createHash } from 'crypto';

declare function countUserAnalyzesToday(userId: string): Promise<number>;
declare function isIpRateLimited(ip: string, limitPerMinute: number): Promise<boolean>;

export async function abuseGuardReplay(params: {
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

  void createHash('sha256').update(params.pdfBuffer).digest('hex');
}
