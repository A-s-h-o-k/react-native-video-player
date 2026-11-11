import { Image, ImageSourcePropType } from 'react-native';
import type { PlayerIcons } from './index';

/**
 * Serializes custom icons map into a JSON string of URI/resource strings.
 */
export function serializeIcons(icons?: PlayerIcons): string | undefined {
  if (!icons) return undefined;
  const serialized: Record<string, string> = {};
  for (const [key, val] of Object.entries(icons)) {
    if (!val) continue;
    if (typeof val === 'string') {
      serialized[key] = val;
    } else {
      const resolved = Image.resolveAssetSource(val as ImageSourcePropType);
      if (resolved?.uri) {
        serialized[key] = resolved.uri;
      }
    }
  }
  return Object.keys(serialized).length > 0 ? JSON.stringify(serialized) : undefined;
}

/**
 * Parses aspect ratio from number or string format (e.g. "16:9", "16/9", "1.777").
 * Returns a positive number or undefined if invalid/non-positive.
 */
export function parseAspectRatio(ratio?: number | string): number | undefined {
  if (typeof ratio === 'number') {
    return ratio > 0 ? ratio : undefined;
  }
  if (typeof ratio === 'string') {
    const trimmed = ratio.trim();
    if (trimmed.includes(':')) {
      const parts = trimmed.split(':').map(Number);
      if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1]) && parts[0] > 0 && parts[1] > 0) {
        return parts[0] / parts[1];
      }
      return undefined;
    } else if (trimmed.includes('/')) {
      const parts = trimmed.split('/').map(Number);
      if (parts.length === 2 && !isNaN(parts[0]) && !isNaN(parts[1]) && parts[0] > 0 && parts[1] > 0) {
        return parts[0] / parts[1];
      }
      return undefined;
    }
    const num = parseFloat(trimmed);
    return !isNaN(num) && num > 0 ? num : undefined;
  }
  return undefined;
}
