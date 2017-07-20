
isUpperCase = (str) ->
  if str.length > 0 then (str[0] >= 'A' && str[0] <= 'Z')
  else false

# increment the chars: a -> b, z -> aa, az -> ba
incrementChars = (str) ->
  return "a" if str.length < 1

  upperCase = isUpperCase(str)
  str = str.toLowerCase() if upperCase

  chars = str.split("")
  carry = 1
  index = chars.length - 1

  while carry != 0 && index >= 0
    nextCharCode = chars[index].charCodeAt() + carry

    if nextCharCode > "z".charCodeAt()
      chars[index] = "a"
      index -= 1
      carry = 1
      lowerCase = 1
    else
      chars[index] = String.fromCharCode(nextCharCode)
      carry = 0

  chars.unshift("a") if carry == 1

  str = chars.join("")
  if upperCase then str.toUpperCase() else str


# ==================================================
# Exports
#

module.exports =
  isUpperCase: isUpperCase
  incrementChars: incrementChars
