#!/bin/bash

echo <<''
wine-app-packager test suite. This will create a package from 7z and check if
everything is ok.

if [ -d ~/.wine-7z-master ]
then
	echo "~/.wine-7z-master already exists, can not run testsuite"
	exit 1
fi

set -e
set -x

sourcedir="$(dirname "`pwd`/$0")"
tmpdir=$(mktemp -t -d wine-app-packager-test.XXXXXXXX)
trap "rm -rf \"$tmpdir\"" EXIT
cd $tmpdir

WAP="$sourcedir/wine-app-packager"

if [ ! -x $WAP ]
then
	echo "$WAP is not executable"
	exit 1
fi

$WAP init 7z <<''
7z
1.2.3


if [ ! -d 7z-1.2.3 ]
then
	echo "init did not create the 7z-1.2.3 directory"
	exit 1
fi

cd 7z-1.2.3

$WAP prepare

if [ ! -d ~/.wine-7z-master ]
then
	echo "init did not create the ~/.wine-7z-master directory"
	exit 1
fi

cp $sourcedir/testdata/7z465.exe ../
$WAP run ../7z465.exe /S
sleep 1

$WAP commit

echo This should fail:
! debuild -uc -us 

echo Setting .exe name in script
sed -i -e 's/EXE=.*/EXE='\''c:\\Programme\\7-Zip\\7zFM.exe'\''/' 7z

echo And now this should work:
debuild -uc -us 

if ! debc | grep -q ./opt/wineapps/wine-7z/drive_c/Programme/7-Zip/7zFM.exe
then
	echo "debc does not contain ./opt/wineapps/wine-7z/drive_c/Programme/7-Zip/7zFM.exe"
	debc
	exit 1
fi

echo "Test suite successfully finished"

