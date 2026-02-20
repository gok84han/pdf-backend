declare function query<T = unknown>(
  sql: string,
  params?: unknown[]
): Promise<{ rows: T[] }>;

declare function releaseReservation(reservationId: string): Promise<void>;
declare function markJobFailed(reservationId: string): Promise<void>;

type ReservationRow = { id: string };
type ExistsRow = { exists: boolean };

export async function cleanupOrphanReservations(): Promise<number> {
  const reservations = await query<ReservationRow>(
    `SELECT id
     FROM quota_reservations
     WHERE status = $1
       AND created_at < NOW() - INTERVAL '15 minutes'`,
    ['RESERVED']
  );

  let releasedCount = 0;

  for (const reservation of reservations.rows) {
    const successJob = await query<ExistsRow>(
      `SELECT EXISTS (
         SELECT 1
         FROM analysis_jobs
         WHERE reservation_id = $1
           AND status = $2
       ) AS exists`,
      [reservation.id, 'SUCCESS']
    );

    if (!successJob.rows[0]?.exists) {
      await releaseReservation(reservation.id);
      await markJobFailed(reservation.id);
      releasedCount += 1;
    }
  }

  return releasedCount;
}
