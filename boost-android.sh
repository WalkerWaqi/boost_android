#!/bin/bash
# Diego Stamigni

BOOST_VERSION="1.59.0"
BOOST_VERSION2=1_59_0

CONFIGDIR="$(pwd)/config"
SCRIPTSDIR="$(pwd)/scripts"
OUTPUTDIR="$(pwd)/android"
BUILDDIR="$(pwd)/android-build"

TOOLSET=gcc-android
STAGEDIR="${BUILDDIR}/stage"
PREFIXDIR="${STAGEDIR}/prefix"
ARCHES=("armeabi" "armeabi-v7a" "arm64-v8a" "x86_64" "x86")

BOOST_DIR="$(pwd)/boost"
BOOST_SRC=$BOOST_DIR/boost_${BOOST_VERSION2}
BOOST_TARBALL=$BOOST_DIR/boost_${BOOST_VERSION}.tar.bz2


downloadBoost()
{
    if [ ! -d $BOOST_DIR ]; then
    	mkdir -p $BOOST_DIR
    fi
    
    if [ ! -s $BOOST_TARBALL ]; then
        echo "Downloading boost ${BOOST_VERSION}"
        curl -L -o $BOOST_TARBALL http://sourceforge.net/projects/boost/files/boost/${BOOST_VERSION}/boost_${BOOST_VERSION2}.tar.bz2/download
    fi
}

unpackBoost()
{
    [ -f $BOOST_TARBALL ] || abort "Source tarball missing."

    echo Unpacking boost into $BOOST_DIR...

    [ -d $BOOST_SRC ] || ( cd $BOOST_DIR; tar xfj $BOOST_TARBALL )
    [ -d $BOOST_SRC ] && echo "    ...unpacked as $BOOST_SRC"
}


if [[ $ANDROID_NDK_ROOT = *[!\ ]* ]]; then
    echo "Using the Android NDK: $ANDROID_NDK_ROOT"
else
    echo "In order to build Boost for Android, please set the env variable ANDROID_NDK_ROOT"
    exit 1
fi

downloadBoost

#source bootstrap.sh

for i in ${!ARCHES[@]} 
do
	ABI=${ARCHES[${i}]}
	
	rm -rf ${BUILDDIR}
	rm -rf ${STAGEDIR}
	rm -rf ${PREFIXDIR}
	rm -rf ${BOOST_SRC}
	
	unpackBoost

	cd $BOOST_SRC
	
	HELPER="${SCRIPTSDIR}/${ABI}".sh
	source "${HELPER}"

	cp "${CONFIGDIR}/${ABI}".jam $(pwd)/tools/build/src/user-config.jam
	cp "${CONFIGDIR}/${ABI}".jam $(pwd)/project-config.jam

	if [[ $BOOST_LIBS = *[!\ ]* ]]; then
		BOOST_LIBS_COMMA=$(echo $BOOST_LIBS | sed -e "s/ /,/g")
		echo "Bootstrapping (with libs $BOOST_LIBS_COMMA)"
		./bootstrap.sh --with-libraries=$BOOST_LIBS_COMMA
	else
		echo "Bootstrapping (with all libs)"
		./bootstrap.sh
	fi

	./bjam -j8 \
		--build-dir="${BUILDDIR}" \
		--stagedir="${STAGEDIR}" \
		--prefix="${PREFIXDIR}" \
		--layout=system \
		architecture=${ARCH} \
		threading=multi \
		link=static \
		target-os=linux \
		toolset=${TOOLSET} \
		install

	# cd "${STAGEDIR}"/prefix/lib
	# ${AR} crus libboost.a *.a

	mkdir -p "${OUTPUTDIR}"/lib/"${ABI}"
	rsync -avp "${PREFIXDIR}"/include "${OUTPUTDIR}"
	rsync -avp "${STAGEDIR}"/prefix/lib/* "${OUTPUTDIR}"/lib/"${ABI}"/
	# cp "${STAGEDIR}"/prefix/lib/libboost.a lib/"${ABI}"/libboost.a
done
