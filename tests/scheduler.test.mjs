import assert from 'node:assert/strict';

const DAY = 24 * 60 * 60 * 1000;
const INTERVALS = { 1: 1, 2: 7, 3: 15, 4: 30, 5: 60, 6: 120 };
function getInitialReviewDate(createdAt) {
  const date = new Date(createdAt);
  if (Number.isNaN(date.getTime())) throw new Error('Data inválida');
  return date;
}
function calculateNextReview(currentLevel, reviewedAt) {
  if (!Number.isInteger(currentLevel) || currentLevel < 0 || currentLevel > 6) throw new Error('Nível inválido');
  const date = new Date(reviewedAt);
  if (Number.isNaN(date.getTime())) throw new Error('Data inválida');
  const newLevel = Math.min(currentLevel + 1, 6);
  const intervalDays = INTERVALS[newLevel];
  return { newLevel, intervalDays, nextReviewAt: new Date(date.getTime() + intervalDays * DAY) };
}
const base = new Date('2026-11-06T12:34:56.000Z');
assert.equal(getInitialReviewDate(base).getTime(), base.getTime(), 'Primeira revisão deve estar disponível imediatamente.');
for (const [level, expectedLevel, days] of [[0,1,1],[1,2,7],[2,3,15],[3,4,30],[4,5,60],[5,6,120],[6,6,120]]) {
  const result = calculateNextReview(level, base);
  assert.equal(result.newLevel, expectedLevel);
  assert.equal(result.intervalDays, days);
  assert.equal(result.nextReviewAt.getTime(), base.getTime() + days * DAY);
}
const late = new Date('2026-12-20T22:00:00.000Z');
const lateResult = calculateNextReview(1, late);
assert.equal(lateResult.nextReviewAt.getTime(), late.getTime() + 7 * DAY, 'A revisão atrasada deve contar a partir do instante real em que foi feita.');
assert.throws(() => calculateNextReview(7, base), /Nível inválido/);
assert.throws(() => calculateNextReview(0, 'data-inválida'), /Data inválida/);
console.log('OK: revisão imediata, 24h após a primeira, intervalos seguintes, teto, atraso e validações.');
