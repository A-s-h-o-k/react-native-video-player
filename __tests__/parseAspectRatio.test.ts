import { parseAspectRatio } from '../src/utils';

describe('parseAspectRatio', () => {
  it('parses "16:9" format', () => {
    const result = parseAspectRatio('16:9');
    expect(result).toBeCloseTo(16 / 9);
  });

  it('parses "16/9" format', () => {
    const result = parseAspectRatio('16/9');
    expect(result).toBeCloseTo(16 / 9);
  });

  it('parses numeric input', () => {
    expect(parseAspectRatio(1.5)).toBe(1.5);
  });

  it('parses numeric string "1.777"', () => {
    expect(parseAspectRatio('1.777')).toBeCloseTo(1.777);
  });

  it('returns undefined for invalid input', () => {
    expect(parseAspectRatio('invalid')).toBeUndefined();
    expect(parseAspectRatio('abc:def')).toBeUndefined();
    expect(parseAspectRatio('16:0')).toBeUndefined();
    expect(parseAspectRatio('0:9')).toBeUndefined();
    expect(parseAspectRatio('16/0')).toBeUndefined();
    expect(parseAspectRatio('0/9')).toBeUndefined();
    expect(parseAspectRatio('1/2/3')).toBeUndefined();
  });

  it('returns undefined for zero', () => {
    expect(parseAspectRatio(0)).toBeUndefined();
    expect(parseAspectRatio('0')).toBeUndefined();
  });

  it('returns undefined for negative values', () => {
    expect(parseAspectRatio(-1)).toBeUndefined();
    expect(parseAspectRatio('-1.5')).toBeUndefined();
    expect(parseAspectRatio('-16:9')).toBeUndefined();
    expect(parseAspectRatio('16:-9')).toBeUndefined();
  });

  it('handles undefined input', () => {
    expect(parseAspectRatio(undefined)).toBeUndefined();
  });
});
