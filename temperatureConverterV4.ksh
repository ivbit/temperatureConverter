#!/bin/ksh

# Intellectual property information START
# 
# Copyright (c) 2021 Ivan Bityutskiy 
# 
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
# 
# Intellectual property information END

# Description START
#
# The script does temperature conversion in real
# time, with instant reaction to user's input.
# The script is written for OpenBSD's pdksh.
#
# Description END

# Shell settings START
set -o noglob
# Shell settings END

# Define functions START
function makeZero
{
  # Function to add zeroes at the end of the value
  integer fracLength="$1"
  (( fracLength < 0 )) && fracLength=0
  integer zeroCounter=0
  local zeroChars=''
  until (( zeroCounter++ == fracLength ))
  do
    zeroChars="${zeroChars}0"
  done
  print -- "$zeroChars"
}

function makeQM
{
  # Function to generate a number of question marks
  local fracValue=${1#*.}
  integer fracLength=$(( ${#fracValue} - $2 ))
  (( fracLength < 0 )) && fracLength=0
  integer qmCounter=0
  local qmChars=''
  until (( qmCounter++ == fracLength ))
  do
    qmChars="${qmChars}?"
  done
  # If there is no question marks, put a placeholder
  [ -z "$qmChars" ] && qmChars='NONE'
  print -- "$qmChars"
}

function fixTemp
{
  local testTemp="$1"
  # Dealing with bc's thing of not printing 0 in 0.5
  [[ "$testTemp" == '.'* ]] && testTemp=" 0$testTemp"
  [[ "$testTemp" == '-.'* ]] && testTemp="-0${testTemp#-}"
  # Dealing with bc returning 0 instead of 0.00
  [[ "$testTemp" == ? ]] && testTemp=" ${testTemp}.$(makeZero $bcScale)"
  # To make all values the same length,
  # dealing with bc not adding zeroes to the right
  local testTempZ="${testTemp#*.}"
  testTemp="${testTemp}$(makeZero $(( bcScale - ${#testTempZ} )))"
  # fix -0.00 after scaling down
  [[ "$testTemp" == '-0.'+(0) ]] && testTemp="${testTemp#-}"
  print -- "$testTemp"
}

function checkMin
{
  # Getting the unit of temperature
  local checkMode=$1
  # Fixing bc's output
  local checkValue="$(fixTemp "$2")"
  # Getting the fractional part of the number
  local checkValueZ="${checkValue#*.}"
  # Reducing the length of checkValueZ to 2 digits
  checkValueZ="${checkValueZ%$(makeQM $checkValueZ 2)}"

  case $checkMode in
    1)
      # 1 is Celsius
      (( (${checkValue%.*} == -273) && (${checkValueZ#0} >= 15) || (${checkValue%.*} <= -274) )) && checkValue="-273.15"
      ;;
    2)
      # 2 is Fahrenheit
      (( (${checkValue%.*} == -459) && (${checkValueZ#0} >= 67) || (${checkValue%.*} <= -460) )) && checkValue="-459.67"
      ;;
    3)
      # 3 is Kelvin
      [[ "$checkValue" == '-'* ]] && checkValue=" 0.00"
      ;;
  esac
  print -- "$checkValue"
}

function printHelp
{
  # Clearing the screen with CSI because use of
  # 'clear' program is slowing down the script
  print -n -- '\033[1;1H\033[0J'
  # Printing hotkey information
  print -u2 -- ' Hotkeys:                   \033[1mq\033[0m quit'
  print -u2 -- ' \033[1m1\033[0m Celsius mode             \033[1mz\033[0m reset to 0'
  print -u2 -- ' \033[1m2\033[0m Fahrenheit mode          \033[1m>\033[0m Increase fractional part'
  print -u2 -- ' \033[1m3\033[0m Kelvin mode              \033[1m<\033[0m Decrease fractional part'

  print -u2 -- ' e -0.0001   degree         i +0.0001   degree'
  print -u2 -- ' r -0.001    degree         u +0.001    degree'
  print -u2 -- ' t -0.01     degree         y +0.01     degree'
  print -u2 -- ' a -0.1      degree         ; +0.1      degree'
  print -u2 -- ' s -0.5      degrees        l +0.5      degrees'
  print -u2 -- ' d -1.0      degree         k +1.0      degree'
  print -u2 -- ' f -5.0      degrees        j +5.0      degrees'
  print -u2 -- ' g -10.0     degrees        h +10.0     degrees'
  print -u2 -- ' v -50.0     degrees        m +50.0     degrees'
  print -u2 -- ' b -100.0    degrees        n +100.0    degrees'
  print -u2 -- '\n'
}

function printAlign
{
  # Function to align values by decimal separator.

  # Mode of the output (Celsius or Fahrenheit or Kelvin)
  local paTmode=$1
  # Getting temperature in Celsius
  local paCtemp="$2"
  [[ "$paCtemp" != '-'* ]] && paCtemp=" $paCtemp"
  # Getting the integer part of the value
  local paCtempInt="${paCtemp%.*}"
  # Getting temperature in Fahrenheit
  local paFtemp="$3"
  [[ "$paFtemp" != '-'* ]] && paFtemp=" $paFtemp"
  # Getting the integer part of the value
  local paFtempInt="${paFtemp%.*}"
  # Getting temperature in Kelvin
  local paKtemp="$4"
  [[ "$paKtemp" != '-'* ]] && paKtemp=" $paKtemp"
  # Getting the integer part of the value
  local paKtempInt="${paKtemp%.*}"

  # Checking againt Celsius, adding spaces
  while (( ${#paCtempInt} > ${#paFtempInt} ))
  do
    paFtemp=" ${paFtemp}"
    paFtempInt="${paFtemp%.*}"
  done
  while (( ${#paCtempInt} > ${#paKtempInt} ))
  do
    paKtemp=" ${paKtemp}"
    paKtempInt="${paKtemp%.*}"
  done

  # Checking againt Fahrenheit, adding spaces
  while (( ${#paFtempInt} > ${#paCtempInt} ))
  do
    paCtemp=" ${paCtemp}"
    paCtempInt="${paCtemp%.*}"
  done
  while (( ${#paFtempInt} > ${#paKtempInt} ))
  do
    paKtemp=" ${paKtemp}"
    paKtempInt="${paKtemp%.*}"
  done

  # Checking againt Kelvin, adding spaces
  while (( ${#paKtempInt} > ${#paCtempInt} ))
  do
    paCtemp=" ${paCtemp}"
    paCtempInt="${paCtemp%.*}"
  done
  while (( ${#paKtempInt} > ${#paFtempInt} ))
  do
    paFtemp=" ${paFtemp}"
    paFtempInt="${paFtemp%.*}"
  done

  # Printing aligned temperatures
  case $paTmode in
    1)
      # Celsius
      # Using \033(0 to use an alternate character set,
      # where f is displayed as a degree symbol
      # Using \033(B to go back to original character set
      print -- "             \033[31mCelsius:      ${paCtemp} \033(0f\033(BC\033[0m"
      print -- "             \033[39mFahrenheit:   ${paFtemp} \033(0f\033(BF\033[0m"
      print -- "             \033[34mKelvin:       ${paKtemp} K\033[0m"
      ;;
    2)
      # Fahrenheit
      print -- "             \033[39mFahrenheit:   ${paFtemp} \033(0f\033(BF\033[0m"
      print -- "             \033[31mCelsius:      ${paCtemp} \033(0f\033(BC\033[0m"
      print -- "             \033[34mKelvin:       ${paKtemp} K\033[0m"
      ;;
    3)
      # Kelvin
      print -- "             \033[34mKelvin:       ${paKtemp} K\033[0m"
      print -- "             \033[31mCelsius:      ${paCtemp} \033(0f\033(BC\033[0m"
      print -- "             \033[39mFahrenheit:   ${paFtemp} \033(0f\033(BF\033[0m"
      ;;
  esac
}

function doBc
{
  # Interact with bc to calculate results
  local calcValue=''
  local bcReply=''
  while (( $# ))
  do
    calcValue="$calcValue $1"
    shift
  done
  print -u8 -- "$calcValue"
  read -u7 -- bcReply
  print -- "$bcReply"
}

function processUserInput
{
  # Processing user's input one letter at a time
  userInput="$(dd bs=1 count=1 2> /dev/null)"
  # Calculating and displaying changes in temperature
  # according to user's input
  integer tempUnit=$1
  local tempValue="$2"
  case $userInput in
    1)
      # Celsius
      print -- "C$tempValue"
      ;;
    2)
      # Fahrenheit
      print -- "F$tempValue"
      ;;
    3)
      # Kelvin
      print -- "K$tempValue"
      ;;

    e|E)
      print -- "four$(checkMin $tempUnit "$(doBc "$tempValue" '-' '0.0001')")"
      ;;
    r|R)
      print -- "three$(checkMin $tempUnit "$(doBc "$tempValue" '-' '0.001')")"
      ;;
    t|T)
      print -- "$(checkMin $tempUnit "$(doBc "$tempValue" '-' '0.01')")"
      ;;
    a|A)
      print -- "$(checkMin $tempUnit "$(doBc "$tempValue" '-' '0.1')")"
      ;;
    s|S)
      print -- "$(checkMin $tempUnit "$(doBc "$tempValue" '-' '0.5')")"
      ;;
    d|D)
      print -- "$(checkMin $tempUnit "$(doBc "$tempValue" '-' 1)")"
      ;;
    f|F)
      print -- "$(checkMin $tempUnit "$(doBc "$tempValue" '-' 5)")"
      ;;
    g|G)
      print -- "$(checkMin $tempUnit "$(doBc "$tempValue" '-' 10)")"
      ;;
    v|V)
      print -- "$(checkMin $tempUnit "$(doBc "$tempValue" '-' 50)")"
      ;;
    b|B)
      print -- "$(checkMin $tempUnit "$(doBc "$tempValue" '-' 100)")"
      ;;

    i|I)
      print -- "four$(doBc "$tempValue" '+' '0.0001')"
      ;;
    u|U)
      print -- "three$(doBc "$tempValue" '+' '0.001')"
      ;;
    y|Y)
      print -- "$(doBc "$tempValue" '+' '0.01')"
      ;;
    \;|\:)
      print -- "$(doBc "$tempValue" '+' '0.1')"
      ;;
    l|L)
      print -- "$(doBc "$tempValue" '+' '0.5')"
      ;;
    k|K)
      print -- "$(doBc "$tempValue" '+' 1)"
      ;;
    j|J)
      print -- "$(doBc "$tempValue" '+' 5)"
      ;;
    h|H)
      print -- "$(doBc "$tempValue" '+' 10)"
      ;;
    m|M)
      print -- "$(doBc "$tempValue" '+' 50)"
      ;;
    n|N)
      print -- "$(doBc "$tempValue" '+' 100)"
      ;;

    # Resetting value to zero
    z|Z)
      print -- " 0.$(makeZero $bcScale)"
      ;;
    # Increasing scale
    \.|\>)
      print -- "I$tempValue"
      ;;
    # Decreasing scale
    \,|\<)
      print -- "D$tempValue"
      ;;
    # Quitting the script
    q|Q)
      print -- 'Q'
      ;;
    # Wrong value, printing current temperature
    *)
      print -- "$tempValue"
      ;;
  esac
}
# Define functions END

# Co-processes START
# Starting bc as a co-process
bc |&
# Making bc reading input from fd7,
# sending output to fd8
exec 7<&p
exec 8>&p
# Co-processes END

# Declare variables START
# Setting the length of fractional part of the value
integer bcScale=2
# Declaring varialble to hold temperature values
typeset cTemp=" 0.$(makeZero $bcScale)" fTemp=" 0.$(makeZero $bcScale)" kTemp=" 0.$(makeZero $bcScale)"
# tempMode's value can be changed to set default unit of
# temperature: 1 - Celsius; 2 - Fahrenheit; 3 - Kelvin
integer tempMode=1
# Saving terminal emulator's settings
sttyBackup="$(stty -g)"
# Declare variables END

# BEGINNING OF SCRIPT
# Hiding the cursor
print -n -- '\033[?25l'
# Disabling canonical input
stty -icanon

# Reading from co-process doesn't work in this mode
while true
do
  # Setting the size of fractional part of the value
  print -u8 -- "scale=$bcScale"
  case $tempMode in
    1)
      # Calling a function to pretty print the temperature
      cTemp="$(fixTemp "$cTemp")"

      fTemp="$(doBc "$cTemp" '*' 9 '/' 5 '+' 32)"
      # Calling a function to pretty print the temperature
      fTemp="$(fixTemp "$fTemp")"

      kTemp="$(doBc "$cTemp" '+' '273.15')"
      # Calling a function to pretty print the temperature
      kTemp="$(fixTemp "$kTemp")"

      # Printing Hotkey information and clearing the screen
      printHelp

      # Printing aligned results
      printAlign $tempMode "$cTemp" "$fTemp" "$kTemp"

      # Calling a function to process user input
      cTemp="$(processUserInput 1 "$cTemp")"
      # Quitting if function returned 'Q'
      [[ "$cTemp" == 'Q' ]] && break
      # Changing temperature mode if function returned 'C', 'F', 'K'
      [[ "$cTemp" == 'C'* ]] && { cTemp="${cTemp#C}"; tempMode=1; }
      [[ "$cTemp" == 'F'* ]] && { cTemp="${cTemp#F}"; tempMode=2; }
      [[ "$cTemp" == 'K'* ]] && { cTemp="${cTemp#K}"; tempMode=3; }
      # Changing scale after 3+ fractional part was changed
      [[ "$cTemp" == 'three'* ]] && { cTemp="${cTemp#three}"; (( (bcScale < 3) && (bcScale=3) )); }
      [[ "$cTemp" == 'four'* ]] && { cTemp="${cTemp#four}"; (( (bcScale < 4) && (bcScale=4) )); }
      # Changing the size of fractional part of the value if function returned 'I', 'D'
      [[ "$cTemp" == 'I'* ]] && { cTemp="${cTemp#I}"; (( (bcScale < 12) && (++bcScale) )); }
      [[ "$cTemp" == 'D'* ]] && { cTemp="${cTemp#D}"; (( (bcScale > 2) && (--bcScale) )); cTemp="${cTemp%$(makeQM "$cTemp" $bcScale)}"; }
      ;;
    2)
      # Calling a function to pretty print the temperature
      fTemp="$(fixTemp "$fTemp")"

      cTemp="$(doBc '(' "$fTemp" '-' 32 ')' '*' 5 '/' 9)"
      # Calling a function to pretty print the temperature
      cTemp="$(fixTemp "$cTemp")"

      kTemp="$(doBc '(' "$fTemp" '+' '459.67' ')' '*' 5 '/' 9)"
      # Calling a function to pretty print the temperature
      kTemp="$(fixTemp "$kTemp")"

      # Printing Hotkey information and clearing the screen
      printHelp

      # Printing aligned results
      printAlign $tempMode "$cTemp" "$fTemp" "$kTemp"

      # Calling a function to process user input
      fTemp="$(processUserInput 2 "$fTemp")"
      # Quitting if function returned 'Q'
      [[ "$fTemp" == 'Q' ]] && break
      # Changing temperature mode if function returned 'C', 'F', 'K'
      [[ "$fTemp" == 'C'* ]] && { fTemp="${fTemp#C}"; tempMode=1; }
      [[ "$fTemp" == 'F'* ]] && { fTemp="${fTemp#F}"; tempMode=2; }
      [[ "$fTemp" == 'K'* ]] && { fTemp="${fTemp#K}"; tempMode=3; }
      # Changing scale after 3+ fractional part was changed
      [[ "$fTemp" == 'three'* ]] && { fTemp="${fTemp#three}"; (( (bcScale < 3) && (bcScale=3) )); }
      [[ "$fTemp" == 'four'* ]] && { fTemp="${fTemp#four}"; (( (bcScale < 4) && (bcScale=4) )); }
      # Changing the size of fractional part of the value if function returned 'I', 'D'
      [[ "$fTemp" == 'I'* ]] && { fTemp="${fTemp#I}"; (( (bcScale < 12) && (++bcScale) )); }
      [[ "$fTemp" == 'D'* ]] && { fTemp="${fTemp#D}"; (( (bcScale > 2) && (--bcScale) )); fTemp="${fTemp%$(makeQM "$fTemp" $bcScale)}"; }
      ;;
    3)
      # Calling a function to pretty print the temperature
      kTemp="$(fixTemp "$kTemp")"

      cTemp="$(doBc "$kTemp" '-' '273.15')"
      # Calling a function to pretty print the temperature
      cTemp="$(fixTemp "$cTemp")"

      fTemp="$(doBc "$kTemp" '*' 9 '/' 5 '-' '459.67')"
      # Calling a function to pretty print the temperature
      fTemp="$(fixTemp "$fTemp")"

      # Printing Hotkey information and clearing the screen
      printHelp

      # Printing aligned results
      printAlign $tempMode "$cTemp" "$fTemp" "$kTemp"

      # Calling a function to process user input
      kTemp="$(processUserInput 3 "$kTemp")"
      # Quitting if function returned 'Q'
      [[ "$kTemp" == 'Q' ]] && break
      # Changing temperature mode if function returned 'C', 'F', 'K'
      [[ "$kTemp" == 'C'* ]] && { kTemp="${kTemp#C}"; tempMode=1; }
      [[ "$kTemp" == 'F'* ]] && { kTemp="${kTemp#F}"; tempMode=2; }
      [[ "$kTemp" == 'K'* ]] && { kTemp="${kTemp#K}"; tempMode=3; }
      # Changing scale after 3+ fractional part was changed
      [[ "$kTemp" == 'three'* ]] && { kTemp="${kTemp#three}"; (( (bcScale < 3) && (bcScale=3) )); }
      [[ "$kTemp" == 'four'* ]] && { kTemp="${kTemp#four}"; (( (bcScale < 4) && (bcScale=4) )); }
      # Changing the size of fractional part of the value if function returned 'I', 'D'
      [[ "$kTemp" == 'I'* ]] && { kTemp="${kTemp#I}"; (( (bcScale < 12) && (++bcScale) )); }
      [[ "$kTemp" == 'D'* ]] && { kTemp="${kTemp#D}"; (( (bcScale > 2) && (--bcScale) )); kTemp="${kTemp%$(makeQM "$kTemp" bcScale)}"; }
      ;;
  esac
done

# Restoring terminal emulator's settings
stty "$sttyBackup"
# Restoring the cursor and printing new line
# to fix the command prompt
print -- '\033[?25h'

# Co-processes START
# Closing the co-process
exec 7<&-
exec 8>&-
# Co-processes END

# Shell settings START
set +o noglob
# Shell settings END

# Exiting script with success status 0
exit 0

# END OF SCRIPT

