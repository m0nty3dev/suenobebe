import * as admin from 'firebase-admin';

admin.initializeApp();

export { validatePlayBillingPurchase, acknowledgePurchase } from './billing/validatePurchase';
export { playBillingRTDN } from './billing/rtdn';
export { recomputeEstimates } from './estimates/recompute';
export { computeDailyStats, computeDailyStatsTask } from './stats/computeDailyStats';
export { checkInactivity } from './notifications/checkInactivity';
export { expireTrials } from './trial/expireTrials';
export { cleanupGracePeriod } from './account/cleanupGracePeriod';
export { createInvitation } from './invitations/create';
export { acceptInvitation } from './invitations/accept';
export { requestAccountDeletion } from './account/requestDeletion';
export { cancelAccountDeletion } from './account/requestDeletion';
export { exportUserData } from './account/exportUserData';
export { recomputeDayKeys } from './events/recomputeDayKeys';
export { createEventCallable } from './events/createEvent';
export { updateEventCallable } from './events/updateEvent';
export { deleteEventCallable } from './events/deleteEvent';
