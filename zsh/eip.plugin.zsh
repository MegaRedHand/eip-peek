# EIP helpers. Titles, descriptions and their caching come from eip-title
# (github.com/MegaRedHand/eip-peek), which checks forkcast.org first, since it
# also tracks EIPs still open as PRs, then eips.ethereum.org.
#
# Every function takes a number in any form: 1559, EIP-1559, ERC-20.
#
# Needs eip-peek's macOS install (macos/install.sh), and gh for the markdown of
# EIPs still open as PRs.

# Where macos/install.sh puts it, so this works without ~/.local/bin on PATH.
_EIP_TITLE=~/.local/bin/eip-title
_EIP_FORKCAST_CACHE=~/Library/Caches/eip-title/forkcast-eips.json

# Prints "owner/repo number" for the PR an EIP is still open in, per forkcast.
_eip_pending_pr() {
  # Refreshes eip-title's copy of forkcast's index when it's stale.
  $_EIP_TITLE "$1" >/dev/null
  [[ -s $_EIP_FORKCAST_CACHE ]] || return 1
  /usr/bin/jq -r --argjson n "$1" \
    '.eips[] | select(.id == $n) | .pendingPullRequest.url // empty' $_EIP_FORKCAST_CACHE \
    | sed -nE 's|^https://github.com/([^/]+/[^/]+)/pull/([0-9]+)$|\1 \2|p'
}

# Opens the EIP's page. EIPs still open as PRs aren't on eips.ethereum.org
# yet, so those open on forkcast instead.
eip() {
  local n=${1//[^0-9]/}
  local url="https://eips.ethereum.org/EIPS/eip-$n"
  curl -fsIL -m 5 -o /dev/null "$url" || url="https://forkcast.org/eips/$n"
  open "$url"
}

# Prints the EIP's raw markdown: from the EIPs repo, then the ERCs repo, then
# the latest commit of the PR the EIP is still open in.
eipraw() {
  local n=${1//[^0-9]/}
  local raw=https://raw.githubusercontent.com
  local fetch=(curl -fsS --retry 2 -m 10)

  "${fetch[@]}" "$raw/ethereum/EIPs/master/EIPS/eip-$n.md" 2>/dev/null && return
  "${fetch[@]}" "$raw/ethereum/ERCs/master/ERCS/erc-$n.md" 2>/dev/null && return

  local pr=($(_eip_pending_pr $n))
  if (( ${#pr} == 2 )); then
    local head dir=EIPS file=eip-$n.md
    [[ ${pr[1]} == */ERCs ]] && dir=ERCS file=erc-$n.md
    # "owner/repo/sha" of the PR's branch, which may live in a fork.
    head=$(gh pr view ${pr[2]} --repo ${pr[1]} \
      --json headRepositoryOwner,headRepository,headRefOid \
      --jq '.headRepositoryOwner.login + "/" + .headRepository.name + "/" + .headRefOid' 2>/dev/null)
    [[ -n $head ]] && "${fetch[@]}" "$raw/$head/$dir/$file" 2>/dev/null && return
  fi

  print -u2 "eipraw: no markdown found for EIP-$n"
  return 1
}

# Shows the title and description of each given EIP.
eipeek() {
  local n lines
  for n in "$@"; do
    # eip-title prints the title, then the description if there is one, then the URL.
    lines=("${(@f)$($_EIP_TITLE "$n")}")
    print -r -- "${lines[1]}"
    if (( ${#lines} == 3 )); then
      print -r -- "    ${lines[2]}"
    fi
  done
}

# Opens the raw EIP markdown with a pager.
eipread() {
  local md
  md=$(eipraw "$1") || return
  print -r -- "$md" | vim -R -c 'set syntax=markdown' -
}
