#!/bin/sh

set -ex

export ARCH=$(uname -m)
REPO="https://api.github.com/repos/mullvad/mullvad-browser/releases/latest"
APPIMAGETOOL="https://github.com/pkgforge-dev/appimagetool-uruntime/releases/download/continuous/appimagetool-$ARCH.AppImage"
UPINFO="gh-releases-zsync|$(echo $GITHUB_REPOSITORY | tr '/' '|')|latest|*$ARCH.AppImage.zsync"
DESKTOP="https://github.com/flathub/net.mullvad.MullvadBrowser/raw/refs/heads/master/net.mullvad.MullvadBrowser.desktop"
export URUNTIME_PRELOAD=1 # really needed here

# ruffle uses amd64 instead of x86_64
tarball_url=$(wget "$REPO" -O - | sed 's/[()",{} ]/\n/g' \
	| grep -oi "https.*linux-$ARCH.*.tar.xz$" | head -1)

export VERSION=$(echo "$tarball_url" | awk -F'/' '{print $(NF-1); exit}')
echo "$VERSION" > ~/version

wget "$tarball_url" -O ./package.tar.xz
tar xvf ./package.tar.xz
rm -f ./package.tar.xz

mv -v ./mullvad-browser ./AppDir && (
	cd ./AppDir
	mv -v ./Browser/* ./

	# don't let the thing set the AppDir as HOME
	sed -i \
		's|browser_home=.*|browser_home="$HOME/.mullvad-browser"|g' \
		./start-mullvad-browser

	cp -v ./browser/chrome/icons/default/default128.png ./mullvad-browser.png
	cp -v ./browser/chrome/icons/default/default128.png ./.DirIcon
	wget "$DESKTOP" -O ./start-mullvad-browser.desktop

	cat > ./AppRun <<- 'KEK'
	#!/bin/sh
	CURRENTDIR="$(dirname "$(readlink -f "$0")")"
	export PATH="${CURRENTDIR}:${PATH}"
	export MOZ_LEGACY_PROFILES=1          # Prevent per installation profiles
	export MOZ_APP_LAUNCHER="${APPIMAGE}" # Allows setting as default browser
	exec "${CURRENTDIR}/start-mullvad-browser" "$@"
	KEK
	chmod +x ./AppRun

	# needed for some reason, otherwise it places the user profile in /tmp
	echo "This is a packaged app." > ./is-packaged-app

	# disable automatic updates
	mkdir -p ./distribution
	cat >> ./distribution/policies.json <<- 'KEK'
	{
	  "policies": {
	    "DisableAppUpdate": true,
	    "AppAutoUpdate": false,
	    "BackgroundAppUpdate": false
	  }
	}
	KEK
)

wget "$APPIMAGETOOL" -O ./appimagetool
chmod +x ./appimagetool
./appimagetool -n -u "$UPINFO" ./AppDir

