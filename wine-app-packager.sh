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

function common_setup () {
	if ! [ -d debian ]
	then
		print "Please run command $0 $1 from within the source directory"
		exit 1;
	fi

	APPNAME="$(grep-dctrl -n -F Source -s Source '' < debian/control)"
	DEBVERSION="$(dpkg-parsechangelog | grep-dctrl -n -s Version '')"
	WINE_MASTER_DIR=~/".wine-$APPNAME-master"
}

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
	Removes ~/.wine-<application>-master afterwards.

wine-app-packager abort
	Just removes ~/.wine-<application>-master, throwing away all changes.
__END__
	exit 1;
fi

if [ "$1" = "init" ]
then
	cat <<__END__
Please enter the name of the application (only lower letters, digits, dots and
dashes. It will be both the package name and the name of the wrapper executable.
Example: wsftp
__END__

	read APPNAME
	if [ -z "$APPNAME" -o -n "$(echo -n "$APPNAME" | tr -d a-z0-9.-)" ]
	then
		echo "Invalid application name \"$APPNAME\"."
		exit 1
	fi

	cat <<__END__
Please enter the upstream version of the application, with the same conventions.
If there is no meaningful version, leave this field empty.
Example: 1.0
__END__

	read APPVER
	if [ -n "$(echo -n "$APPVER" | tr -d a-z0-9.-)" ]
	then
		echo "Invalid application version \"$APPVER\"."
		exit 1
	fi

	if [ -z "$APPVER" ]
	then
		DEBVER="1"
	else
		DEBVER="$APPVER"
	fi
	DEBDIR="$APPNAME-$DEBVER"

	if [ -e "$DEBDIR" ]
	then
		cat <<__END__
The directory \"$DEBDIR\" does already exist. Please remove it if you want to
start from scratch.
__END__

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
		cat <<__END__
WARNING: DEBFULLNAME and DEBEMAIL not set. Please adjust maintainer field
in debian/control and debian/changelog afterwards.
__END__
		MAINT="Someone <please-update@in.here>"
	fi
	cat >"$DEBDIR/debian/control" <<__END__
Source: $APPNAME
Maintainer: $MAINT

Package: $APPNAME
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
 	debchange --create --package "$APPNAME" --newversion "$DEBVER-1" --distribution UNRELEASED "First release of $APPNAME"
	popd
	cat <<__END__
Done preparing the source package. You can review the contents of these files
now, or go ahead with wine-app-packager prepare, from within the created source
directory in $DEBDIR.
__END__

elif [ "$1" = "prepare" ]
then
	common_setup

	if [ -e "$WINE_MASTER_DIR" ]
	then
		cat <<__END__
Directory $WINE_MASTER_DIR already exists. If it contains changes
that need to be preserved, please use $0 commit, otherwise remove
it before running $0 $1.
__END__
		exit 1
	fi

	if [ -d drive_c ]
	then
		echo "Creating $WINE_MASTER_DIR"
		mkdir "$WINE_MASTER_DIR"
		echo "Extracting ./wine-config.tar.gz to $WINE_MASTER_DIR"
		tar --extract --gzip --file ./wine-config.tar.gz -C "$WINE_MASTER_DIR"
		echo "Copying ./drive_c to $WINE_MASTER_DIR/drive_c"
		rsync --recursive ./drive_c/ $WINE_MASTER_DIR/drive_c
	else
		echo "Empty package, creating empty $WINE_MASTER_DIR"
		mkdir "$WINE_MASTER_DIR"
	fi
elif [ "$1" = "run" ]
then
	common_setup

	if [ ! -d "$WINE_MASTER_DIR" ]
	then
		cat <<__END__
Directory $WINE_MASTER_DIR does not exist. Please run $0 $1 prepare first.
__END__
		exit 1
	fi

	if [ -z "$2" ]
	then
		cat <<__END__
You need to pass a program to be run, e.g. $0 $1 wine setup.exe
__END__
		exit 1
	fi

	export WINEPREFIX=$WINE_MASTER_DIR
	shift
	exec "$@"
elif [ "$1" = "commit" ]
then
	common_setup

	if [ ! -d "$WINE_MASTER_DIR" ]
	then
		cat <<__END__
Directory $WINE_MASTER_DIR does not exist. Please run $0 $1 prepare first.
__END__
		exit 1
	fi

	echo "Copying over $WINE_MASTER_DIR in a tarfile, excluding drive_c"
	tar --create --file ./wine-config.tar.gz --gzip --directory "$WINE_MASTER_DIR" --exclude drive_c .
	echo "Copying over drive_c, excluding Profiles"
	rsync --recursive --delete --exclude windows/profiles --exclude windows/temp "$WINE_MASTER_DIR/drive_c/" drive_c

	echo "Removing $WINE_MASTER_DIR"
	rm -rf "$WINE_MASTER_DIR"
	cat <<__END__
Change are propagated to the Debian source directory. To build the package,
increase the version number with "debchange -i" and build it with dpkg-buildpackage.
__END__

elif [ "$1" = "abort" ]
then
	common_setup

	if [ ! -d "$WINE_MASTER_DIR" ]
	then
		cat <<__END__
Directory $WINE_MASTER_DIR does not exist, nothing to abort.
__END__
		exit 1
	fi

	echo "Removing $WINE_MASTER_DIR"
	rm -rf "$WINE_MASTER_DIR"
else
	echo "Unknown command $1. Please run $0 without commands for a usage summary."
	exit 1
fi
