#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for dagger.
GH_REPO="https://github.com/dagger/dagger"
DL_URL="https://dagger-io.s3.amazonaws.com/dagger"
TOOL_NAME="dagger"
TOOL_TEST="dagger --help"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if dagger is not hosted on GitHub releases.
sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

# NOTE: You might want to remove this if dagger is not hosted on GitHub releases.
list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

list_all_versions() {
  list_github_tags
}

get_arch() {
  local arch=""

  case "$(uname -m)" in
    x86_64 | amd64) arch='amd64' ;;
    aarch64 | arm64) arch="arm64" ;;
    *)
      fail "Arch '$(uname -m)' not supported!"
      ;;
  esac

  echo -n $arch
}

get_platform() {
  local platform=""

  case "$(uname | tr '[:upper:]' '[:lower:]')" in
    darwin) platform="darwin" ;;
    linux) platform="linux" ;;
    windows) platform="windows" ;;
    *)
      fail "Platform '$(uname -m)' not supported!"
      ;;
  esac

  echo -n $platform
}

latest_version() {
  curl -sfL "$DL_URL/latest_version"
}

download_release() {
  local version filename url
  version="$1"
  if [ "$version" == "latest" ]; then
    version="$(latest_version)"
  fi

  filename="$2"

  platform=$(get_platform)
  arch=$(get_arch)
  ext=".tar.gz"
  if [ "$platform" == "windows" ]; then
    ext=".zip"
  fi

  # TODO: Adapt the release URL convention for dagger
  url="$DL_URL/releases/${version}/dagger_v${version}_${platform}_${arch}${ext}"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path/bin"
    cp "$ASDF_DOWNLOAD_PATH/dagger" "$install_path/bin/dagger"

    # TODO: Asert dagger executable exists.
    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
