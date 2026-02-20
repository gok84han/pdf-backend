declare function releaseReservation(reservationId: string): Promise<void>;

export async function ensureRelease(
  reservation: { id: string; status: string },
  jobStatus: 'SUCCESS' | 'FAILED'
): Promise<void> {
  if (reservation.status === 'RESERVED' && jobStatus !== 'SUCCESS') {
    await releaseReservation(reservation.id);
  }
}

