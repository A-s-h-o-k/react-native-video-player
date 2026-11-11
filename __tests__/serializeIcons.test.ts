import { Image } from 'react-native';
import { serializeIcons } from '../src/utils';

describe('serializeIcons', () => {
  it('returns undefined for undefined input', () => {
    expect(serializeIcons(undefined)).toBeUndefined();
  });

  it('returns undefined for empty icons object', () => {
    expect(serializeIcons({})).toBeUndefined();
  });

  it('returns undefined when all icon entries are falsy or empty strings', () => {
    expect(
      serializeIcons({
        play: '',
        pause: undefined,
      })
    ).toBeUndefined();
  });

  it('serializes string icon identifiers correctly', () => {
    const icons = {
      play: 'play.fill',
      pause: 'pause.fill',
      rewind: 'gobackward.15',
    };
    const result = serializeIcons(icons);
    expect(result).toBeDefined();
    const parsed = JSON.parse(result!);
    expect(parsed).toEqual({
      play: 'play.fill',
      pause: 'pause.fill',
      rewind: 'gobackward.15',
    });
  });

  it('resolves image asset numbers via Image.resolveAssetSource', () => {
    jest.spyOn(Image, 'resolveAssetSource').mockReturnValue({
      uri: 'http://example.com/custom_play.png',
      width: 64,
      height: 64,
      scale: 1,
    });

    const icons = {
      play: 1234, // Simulated require() asset id
    };
    const result = serializeIcons(icons as any);
    expect(result).toBeDefined();
    const parsed = JSON.parse(result!);
    expect(parsed.play).toBe('http://example.com/custom_play.png');

    (Image.resolveAssetSource as jest.Mock).mockRestore();
  });
});
