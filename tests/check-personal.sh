#!/bin/zsh
# Fail when a tracked file, or a commit author, would publish something personal: a home folder path, an e-mail
# address, or this Mac's login name. The author credit (Ivan Gonzalez, tomacco, tomac.co) is intended and allowed.
# Runs in CI and in .githooks/pre-commit.   zsh tests/check-personal.sh
cd "${0:A:h:h}"
bad=0
# --artifact <app>: scan a built app's bytes instead (the release zip ships it to every user).
if [[ $1 == --artifact ]]; then
  found=$(grep -a -r -o -E '/(Users|home)/[A-Za-z0-9._-]+' -- "$2" | grep -v -E ':/Users/Shared$' | sort -u)
  me=$(id -un); [[ ${#me} -ge 4 ]] && found+=$'\n'$(grep -a -r -l -F -- "$me" "$2")
  [[ -n ${found//$'\n'} ]] && { print -r -- "personal: $2 holds
$found" | sed "s/$me/<login>/g"; exit 1 }
  print "personal: $2 clean"; exit 0
fi
hit() { print -- "personal: $1"; bad=1 }
files=(${(f)"$(git ls-files | grep -v '^mod/vendor/')"})
paths=$(grep -n -I -o -E '/(Users|home)/[A-Za-z0-9._-]+' -- $files 2>/dev/null | grep -v -E ':/Users/(x|Shared)$|:/home/(runner|user)$')
[[ -n $paths ]] && hit "home folder paths\n$paths"
mails=$(grep -n -I -o -E '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+\.[A-Za-z.]{2,}' -- $files 2>/dev/null \
  | grep -v -E ':(git@github\.com|noreply@anthropic\.com|[A-Za-z0-9-]+@users\.noreply\.github\.com)$')
[[ -n $mails ]] && hit "e-mail addresses\n$mails"
# The login name on this machine (CI runners have generic ones). The vendored backlog tool leaked it once.
me=$(id -un)
if [[ $me != (runner|root|user) && ${#me} -ge 4 ]]; then
  login=$(grep -n -I -F -- "$me" $files 2>/dev/null)
  [[ -n $login ]] && hit "the login name $me\n$login"
fi
# Commit authors and committers: GitHub noreply addresses only.
authors=$(git log --format='%ae%n%ce' | sort -u | grep -v -E '@users\.noreply\.github\.com$|^noreply@github\.com$')
[[ -n $authors ]] && hit "commit addresses\n$authors"
(( bad )) || print "personal: clean (${#files} files, $(git rev-list --count HEAD) commits)"
exit $bad
