# HOMEBREW_LIBRARY set by bin/brew
# shellcheck disable=SC2154
export HOMEBREW_REQUIRED_GIT_VERSION="2.53.0"
HOMEBREW_PORTABLE_GIT_VERSION="$(cat "${HOMEBREW_LIBRARY}/Homebrew/vendor/portable-git-version")"

# HOMEBREW_LIBRARY set by bin/brew
# shellcheck disable=SC2154
test_git() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  "$1" --version >/dev/null 2>&1
}

system_git_supported() {
  for git_exec_path in $(whence -a git)
  do
    if test_git "${git_exec_path}"
    then
      return 0
    fi
  done

  return 1
}

find_first_valid_git() {
  local git_exec
  while IFS= read -r git_exec
  do
    if test_git "${git_exec}"
    then
      echo "${git_exec}"
      break
    fi
  done
}

# HOMEBREW_PATH is set by global.rb
# shellcheck disable=SC2154
find_git() {
  local valid_git

  # Prioritise git from the filtered path (/usr/bin etc) unless explicitly overridden.
  # shellcheck disable=SC2230
  valid_git=$(find_first_valid_git < <(whence -a git))

  if [[ -z "${valid_git}" ]]
  then
    # Same as above
    # shellcheck disable=SC2230
    valid_git=$(find_first_valid_git < <(PATH="${HOMEBREW_PATH}" whence -a git))
  fi

  echo "${valid_git}"
}

# HOMEBREW_FORCE_VENDOR_GIT is from the user environment
# shellcheck disable=SC2154
need_vendored_git() {
  if [[ -n "${HOMEBREW_FORCE_VENDOR_GIT}" ]]
  then
    return 0
  elif system_git_supported && test_git "${HOMEBREW_VENDOR_GIT_PATH}"
  then
    return 1
  else
    return 0
  fi
}

# HOMEBREW_LINUX is set by brew.sh
# shellcheck disable=SC2154
setup-vendor-git-path() {
  local vendor_dir
  local vendor_git_root
  local vendor_git_path
  local vendor_git_terminfo
  local vendor_git_current_version
  local git_exec
  local upgrade_fail
  local install_fail

  local advice="
If there's no Homebrew Portable Git available for your processor:
- install Git ${HOMEBREW_REQUIRED_GIT_VERSION} with your system package manager
- make it first in your PATH
- try again
"
  upgrade_fail="Failed to upgrade Homebrew Portable Git!${advice}"
  install_fail="Failed to install Homebrew Portable Git and cannot find another Git ${HOMEBREW_REQUIRED_GIT_VERSION}!${advice}"

  vendor_dir="${HOMEBREW_LIBRARY}/Homebrew/vendor"
  vendor_git_root="${vendor_dir}/portable-git/current"
  vendor_git_path="${vendor_git_root}/bin/git"
  vendor_git_terminfo="${vendor_git_root}/share/terminfo"
  vendor_git_current_version="$(readlink "${vendor_git_root}")"

  if [[ -n "${HOMEBREW_GIT_PATH}" ]] || system_git_supported
  then
    HOMEBREW_VENDOR_GIT_PATH=""
  elif [[ -x "${vendor_git_path}" ]]
  then
    HOMEBREW_VENDOR_GIT_PATH="${vendor_git_path}"
    TERMINFO_DIRS="${vendor_git_terminfo}"
    if [[ "${vendor_git_current_version}" != "${HOMEBREW_PORTABLE_GIT_VERSION}" ]]
    then
      brew vendor-install git || odie "${upgrade_fail}"
    fi
  else
    if need_vendored_git
    then
      brew vendor-install git || odie "${install_fail}"
      HOMEBREW_VENDOR_GIT_PATH="${vendor_git_path}"
    fi
  fi

  export HOMEBREW_VENDOR_GIT_PATH
}

