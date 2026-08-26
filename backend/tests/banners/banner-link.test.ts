import { describe, it, expect } from 'vitest';
import {
  parseBannerLink,
  formatBannerLink,
} from '../../src/modules/banners/banner-link.js';

describe('parseBannerLink', () => {
  it('parses each supported kind', () => {
    expect(parseBannerLink('product:sp2rhACi')).toEqual({
      kind: 'product',
      value: 'sp2rhACi',
    });
    expect(parseBannerLink('category:home-kitchen')).toEqual({
      kind: 'category',
      value: 'home-kitchen',
    });
    expect(parseBannerLink('shop:sharma-electronics')).toEqual({
      kind: 'shop',
      value: 'sharma-electronics',
    });
    expect(parseBannerLink('search:winter jackets')).toEqual({
      kind: 'search',
      value: 'winter jackets',
    });
  });

  it('tolerates surrounding whitespace and kind casing', () => {
    expect(parseBannerLink('  Category: Home-Kitchen  ')).toEqual({
      kind: 'category',
      value: 'home-kitchen',
    });
  });

  it('keeps a search phrase verbatim, including its case and spaces', () => {
    expect(parseBannerLink('search:Winter Jackets')).toEqual({
      kind: 'search',
      value: 'Winter Jackets',
    });
  });

  it('returns null for the legacy formats, rather than guessing', () => {
    expect(parseBannerLink('https://example.com/sale')).toBeNull();
    expect(parseBannerLink('/shop/acme')).toBeNull();
    expect(parseBannerLink('url:https://example.com')).toBeNull();
  });

  it('rejects an unknown kind', () => {
    expect(parseBannerLink('collection:summer')).toBeNull();
    expect(parseBannerLink('promo:xyz')).toBeNull();
  });

  it('rejects a malformed value for its kind', () => {
    expect(parseBannerLink('category:Home Kitchen')).toBeNull();
    expect(parseBannerLink('category:home_kitchen')).toBeNull();
    expect(parseBannerLink('shop:-leading-hyphen')).toBeNull();
    expect(parseBannerLink('product:has spaces')).toBeNull();
  });

  it('rejects empty, missing and separator-less input', () => {
    expect(parseBannerLink(null)).toBeNull();
    expect(parseBannerLink(undefined)).toBeNull();
    expect(parseBannerLink('')).toBeNull();
    expect(parseBannerLink('   ')).toBeNull();
    expect(parseBannerLink('product:')).toBeNull();
    expect(parseBannerLink('product')).toBeNull();
    expect(parseBannerLink(':value')).toBeNull();
  });

  it('caps a search phrase so a link cannot carry a payload', () => {
    expect(parseBannerLink(`search:${'a'.repeat(120)}`)).not.toBeNull();
    expect(parseBannerLink(`search:${'a'.repeat(121)}`)).toBeNull();
  });

  it('round-trips through formatBannerLink', () => {
    for (const raw of [
      'product:sp2rhACi',
      'category:home-kitchen',
      'shop:sharma-electronics',
      'search:winter jackets',
    ]) {
      const parsed = parseBannerLink(raw)!;
      expect(formatBannerLink(parsed)).toBe(raw);
      expect(parseBannerLink(formatBannerLink(parsed))).toEqual(parsed);
    }
  });
});
