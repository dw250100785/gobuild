#!/bin/bash -
#
# gorelease.sh: build and publish
#
# shorted url: <http://bitly.com/gorelease>
# need login to view stats: https://bitly.com/a/stats
#
# ref:
# - [travis-ci environment](http://docs.travis-ci.com/user/environment-variables/)

set -e
set -o pipefail

echo "Is Pull Request: $TRAVIS_PULL_REQUEST"
# Set environment variables
GORELEASE_GO_VERSION="1.5"
BUILD_OS=${1:-"windows linux darwin"}
TMPDIR=$PWD/gorelease-temp
BRANCH=

if test -z "$TRAVIS"
then
	# Here for my test
	BRANCH=$(git symbolic-ref --short HEAD)
	ACCESS_KEY=V6cm-H-uL5Lh0hrPbF28Y1KJ99dW8d2p9lUQRDMJ
	SECRET_KEY=gFatds2RE8MWZSqbVOwsztp8EAqtHUOnWC6NGKVU
	BUCKET=gorelease
else
	BRANCH=${TRAVIS_BRANCH:-$TRAVIS_TAG}
	ACCESS_KEY=${ACCESS_KEY:?}
	SECRET_KEY=${SECRET_KEY:?}
	BUCKET=${BUCKET:?}
fi
KEY_PREFIX=/gorelease/${PWD#*/src/github.com}/${BRANCH:?}/

echo "Branch: $BRANCH"
echo "KeyPrefix: $KEY_PREFIX"

if test -n "$TRAVIS" -a "X$TRAVIS_GO_VERSION" != "X$GORELEASE_GO_VERSION"; then
	echo "Expect go$GORELEASE_GO_VERSION, but travis got go$TRAVIS_GO_VERSION"
	exit 0
fi

# Set build environment
if test -n "$TRAVIS"
then
	go get github.com/mitchellh/gox
	if test $GORELEASE_GO_VERSION != "1.5"
	then
		gox -os="${BUILD_OS}" -build-toolchain
	fi
	go get github.com/gorelease/qsync
else
	BUILD_OS="darwin"
fi


/bin/mkdir -p $TMPDIR
DISTDIR=$TMPDIR/dist

# FIXME(ssx): need support build pack
# build standalone
gox -os "$BUILD_OS" -output "$DISTDIR/{{.OS}}-{{.Arch}}/{{.Dir}}"

#GOOS=$(go env GOOS)
#GOARCH=$(go env GOARCH)
#wget -q http://devtools.qiniu.com/qiniu-devtools-${GOOS}_${GOARCH}-current.tar.gz -O- | tar -xz -C $TMPDIR
#/bin/rm -fr $HOME/.qrsync


cat > $TMPDIR/conf.ini <<EOF
[qiniu]
uphost = http://up.qiniug.com
bucket = $BUCKET
accesskey = "$ACCESS_KEY"
secretkey = "$SECRET_KEY"
keyprefix = $KEY_PREFIX

[local]
syncdir = $DISTDIR

[gorelease]
token = "$GORELEASE_TOKEN"
host = "qntoken.herokuapp.com"
EOF

set -eu

cat > $DISTDIR/builds.json <<EOF
{
	"update_time": $(date +%s),
	"go_version": "$GORELEASE_GO_VERSION"
}
EOF

# upload
qsync -c $TMPDIR/conf.ini
