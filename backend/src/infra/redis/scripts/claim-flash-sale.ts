/// Atomic claim against a flash-sale stock counter.
///
/// KEYS[1] = sold counter key (e.g. "flash:42:sold")
/// ARGV[1] = qty to claim (integer)
/// ARGV[2] = stockLimit (integer) — fresh-from-DB on every call so a
///           merchant-side limit change is enforced on the very next
///           claim
/// ARGV[3] = TTL seconds — refreshed on every successful claim so the
///           counter doesn't expire mid-sale
///
/// Returns -1 when current+qty would exceed the limit, otherwise the
/// new sold total. Redis runs this script atomically so two concurrent
/// claims can never both see "room for one more" and both succeed past
/// the cap.
export const CLAIM_FLASH_SALE_LUA = `
local current = tonumber(redis.call('GET', KEYS[1]) or '0')
local qty = tonumber(ARGV[1])
local limit = tonumber(ARGV[2])
local ttl = tonumber(ARGV[3])
if current + qty > limit then
  return -1
end
local total = redis.call('INCRBY', KEYS[1], qty)
redis.call('EXPIRE', KEYS[1], ttl)
return total
`;
