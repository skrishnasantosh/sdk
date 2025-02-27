#!/bin/sh

UV_VERSION="1.42.0"
SDKVERSION=`xcrun -sdk iphoneos --show-sdk-version`

##############################################
CURRENTPATH=`pwd`
OPENSSL_PREFIX="${CURRENTPATH}"
ARCHS="x86_64 arm64 arm64-simulator"
DEVELOPER=`xcode-select -print-path`

CORES=$(sysctl -n hw.ncpu)

# Formating
green="\033[32m"
bold="\033[0m${green}\033[1m"
normal="\033[0m"


if [ ! -d "$DEVELOPER" ]; then
  echo "xcode path is not set correctly $DEVELOPER does not exist (most likely because of xcode > 4.3)"
  echo "run"
  echo "sudo xcode-select -switch <xcode path>"
  echo "for default installation:"
  echo "sudo xcode-select -switch /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

case $DEVELOPER in
     *\ * )
           echo "Your Xcode path contains whitespaces, which is not supported."
           exit 1
          ;;
esac

case $CURRENTPATH in
     *\ * )
           echo "Your path contains whitespaces, which is not supported by 'make install'."
           exit 1
          ;;
esac

set -e

if [ ! -e "libuv-v${UV_VERSION}.tar.gz" ]
then
curl -LO "http://dist.libuv.org/dist/v${UV_VERSION}/libuv-v${UV_VERSION}.tar.gz"
fi

for ARCH in ${ARCHS}
do
if [[ "${ARCH}" == "x86_64" || "${ARCH}" == "arm64-simulator" ]];
then
PLATFORM="iPhoneSimulator"
if [ "${ARCH}" == "arm64-simulator" ];
then
ARCH="arm64"
fi
else
PLATFORM="iPhoneOS"
fi

rm -rf libuv-v${UV_VERSION}
tar zxf libuv-v${UV_VERSION}.tar.gz
pushd "libuv-v${UV_VERSION}"

echo "${bold}Building libuv for $PLATFORM $ARCH ${normal}"

export BUILD_TOOLS="${DEVELOPER}"
export BUILD_DEVROOT="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
export BUILD_SDKROOT="${BUILD_DEVROOT}/SDKs/${PLATFORM}${SDKVERSION}.sdk"

RUNTARGET=""
if [[ "${ARCH}" == "arm64"  && "$PLATFORM" == "iPhoneSimulator" ]];
then
RUNTARGET="-target ${ARCH}-apple-ios13.0-simulator"
fi

export CC="${BUILD_TOOLS}/usr/bin/gcc -arch ${ARCH}"
mkdir -p "${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"

# Build
export LDFLAGS="-Os -arch ${ARCH} -Wl,-dead_strip -miphoneos-version-min=13.0"
export CFLAGS="-Os -arch ${ARCH} -pipe -no-cpp-precomp -isysroot ${BUILD_SDKROOT} -miphoneos-version-min=13.0 ${RUNTARGET}"
export CPPFLAGS="${CFLAGS} -DNDEBUG"
export CXXFLAGS="${CPPFLAGS}"

sh autogen.sh

if [ "${ARCH}" == "arm64" ]; then
./configure --host=arm-apple-darwin --enable-static --disable-shared
else
./configure --host=${ARCH}-apple-darwin --enable-static --disable-shared
fi

make -j${CORES}
cp -f .libs/libuv.a ${CURRENTPATH}/bin/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/
#make clean

popd

done


mkdir lib || true
lipo -create ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-x86_64.sdk/libuv.a ${CURRENTPATH}/bin/iPhoneSimulator${SDKVERSION}-arm64.sdk/libuv.a -output ${CURRENTPATH}/bin/libuv.a

echo "${bold}Creating xcframework ${normal}"

xcodebuild -create-xcframework -library ${CURRENTPATH}/bin/libuv.a -library ${CURRENTPATH}/bin/iPhoneOS${SDKVERSION}-arm64.sdk/libuv.a -output ${CURRENTPATH}/xcframework/libuv.xcframework

mkdir -p include || true
cp -f -R libuv-v${UV_VERSION}/include/ include/

echo "${bold}Cleaning up ${normal}"
rm -rf bin
rm -rf libuv-v${UV_VERSION}
rm -rf libuv-v${UV_VERSION}.tar.gz


echo "Done."
