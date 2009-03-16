#!/bin/bash

# TODO:
# * LHM-Wine-Pakete beachten

set -e

#
# © 2009 Joachim Breitner <joachim.breitner@itomig.de>
#
# Licensed under the EUPL, Version 1.0 or – as soon they
# will be approved by the European Commission - subsequent
# versions of the EUPL (the "Licence");
# you may not use this work except in compliance with the
# Licence.
# You may obtain a copy of the Licence at:
# 
# http://ec.europa.eu/idabc/7330l5
# 
# Unless required by applicable law or agreed to in
# writing, software distributed under the Licence is
# distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
# express or implied.
# See the Licence for the specific language governing
# permissions and limitations under the Licence.

if [ ! "$1" ]
then
	cat <<'__END__'
wine-app-packager
=================

This script aids you in creation of Debian packages of Windows applications
that are meant to run under wine. It offers the following commands:

wine-app-packager init
	creates a Debian source package directory. It will ask various pieces
	of information. All the following commands will need to run within the
	created directory.

wine-app-packager prepare
	Creates a wine config directory in ~/.wine-<application>-master, based on
	the current content of the package (if any).

wine-app-packager run <cmd>
	Runs cmd in a way that WINEPREFIX is set correctly, i.e.
	wine-app-packager run wine /tmp/install.exe
	or
	wine-app-packager run wine C:\\Applications\\DemoApplication\\DemoApplication.exe

wine-app-packager commit
	Takes the changes you made in ~/.wine-<application>-master and puts them
	back into the Debian source package. Ususally, this will be followed by
	calls to debchange and debuilt to build the package
__END__
	exit 1;
fi

if [ "$1" = "init" ]
then
	cat <<''
Please enter the name of the application (only lower letters, digits, dots and
dashes. It will be both the package name and the name of the wrapper executable.
Example: wsftp

	read APPNAME
	if [ -z "$APPNAME" -o -n "$(echo -n "$APPNAME" | tr -d a-z0-9.-)" ]
	then
		echo "Invalid application name \"$APPNAME\"."
		exit 1
	fi

	cat <<''
Please enter the upstream version of the application, with the same conventions.
If there is no meaningful version, leave this field empty.
Example: 1.0

	read APPVER
	if [ -n "$(echo -n "$APPVER" | tr -d a-z0-9.-)" ]
	then
		echo "Invalid application version \"$APPVER\"."
		exit 1
	fi

	if [ -z "$APPVER" ]
	then
		DEBNAME="$APPNAME"
		DEBVER="1"
	else
		DEBNAME="$APPNAME"
		DEBVER="$APPVER"
	fi
	DEBDIR="$DEBNAME-$DEBVER"

	if [ -e "$DEBDIR" ]
	then
		echo <<""
The directory \"$DEBDIR\" does already exist. Please remove it if you want to
start from scratch.

		exit 1
	fi
	echo "Creating directory \"$DEBDIR\"."
	mkdir "$DEBDIR"
	mkdir "$DEBDIR"/debian
	echo "Writing \"$DEBDIR/debian/control\""

	if [ -n "$DEBFULLNAME" ]
	then
		MAINT="$DEBFULLNAME <$DEBEMAIL>"
	else
		echo <<''
WARNING: DEBFULLNAME and DEBEMAIL not set. Please adjust maintainer field
in debian/control and debian/changelog afterwards.

		MAINT="Someone <please-update@in.here>"
	fi
	cat >"$DEBDIR/debian/control" <<__END__
Source: $DEBNAME
Maintainer: $MAINT

Package: $DEBNAME
Architecture: i386
Depends: wine
Description: Application $APPNAME
 This is a windows application packaged for Debian clients.
__END__
	echo "Writing \"$DEBDIR/debian/compat\""
	echo 5 > "$DEBDIR/debian/compat"
	echo "Writing \"$DEBDIR/debian/rules\""
	cat >"$DEBDIR/debian/rules" <<__END__
#!/usr/bin/make -f
clean:
	dh_testdir
	dh_testroot
	dh_clean

install: build
	dh_testdir
	dh_testroot
	dh_clean -k
	dh_installdirs

	# Add here commands to install the package into debian/<packagename>
	#\$(MAKE) prefix=\`pwd\`/debian/\`dh_listpackages\`/usr install

binary-indep: install

# Build architecture-dependent files here.
binary-arch: install
	dh_testdir
	dh_testroot
	dh_installchangelogs
	dh_installdocs
	dh_installexamples
	dh_install
	dh_installman
	dh_link
	dh_strip
	dh_compress
	dh_fixperms
	dh_installdeb
	dh_shlibdeps
	dh_gencontrol
	dh_md5sums
	dh_builddeb

binary: binary-indep binary-arch
.PHONY: clean binary-indep binary-arch binary install
__END__
	echo "Generating \"$DEBDIR/debian/changelog\""
	pushd "$DEBDIR"
 	debchange --create --package "$DEBNAME" --newversion "$DEBVER-1" --distribution UNRELEASED "First release of $APPNAME"
	popd
	echo <<''
Done preparing the source package. You can review the contents of these files
now, or go ahead with wine-app-packager prepare.

fi
	
