-- util/hash.lua
-- Small deterministic non-cryptographic hash for duplicate name suffixes.
-- Good enough for user-facing duplicate keys; replace with SHA-1/SHA-256 if a
-- verified pure-Lua implementation is already available in the target driver.

local M = {}

function M.short_hash(s)
  s = tostring(s or "")
  local h = 5381
  for i = 1, #s do
    h = (h * 33 + s:byte(i)) % 4294967296
  end
  return string.format("%08x", h)
end

return M
