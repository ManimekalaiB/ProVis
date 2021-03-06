#!/usr/bin/env bash
# ##### BEGIN GPL LICENSE BLOCK #####
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software Foundation,
#  Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# ##### END GPL LICENSE BLOCK #####

# A shell script installing/building all needed dependencies to build Blender, for some Linux distributions.

##### Args and Help Handling #####

# Parse command line!
ARGS=$( \
getopt \
-o s:i:t:h \
--long source:,install:,tmp:,threads:,help,with-all,with-osl,with-opencollada,all-static,force-all,\
force-python,force-numpy,force-boost,force-ocio,force-oiio,force-llvm,force-osl,force-opencollada,\
force-ffmpeg,skip-python,skip-numpy,skip-boost,skip-ocio,skip-oiio,skip-llvm,skip-osl,skip-ffmpeg,\
skip-opencollada \
-- "$@" \
)

DISTRO=""
RPM=""
SRC="$HOME/src/blender-deps"
INST="/opt/lib"
TMP="/tmp"
CWD=$PWD

# Do not install some optional, potentially conflicting libs by default...
WITH_ALL=false

# Do not yet enable osl, use --with-osl (or --with-all) option to try it.
WITH_OSL=false

# Do not yet enable opencollada, use --with-opencollada (or --with-all) option to try it.
WITH_OPENCOLLADA=false

# Try to link everything statically. Use this to produce portable versions of blender.
ALL_STATIC=false

THREADS=`cat /proc/cpuinfo | grep cores | uniq | sed -e "s/.*: *\(.*\)/\\1/"`
if [ -z "$THREADS" ]; then
  THREADS=1
fi

COMMON_INFO="\"Source code of dependencies needed to be compiled will be downloaded and extracted into '\$SRC'.
Built libs of dependencies needed to be compiled will be installed into '\$INST'.
Please edit \\\$SRC and/or \\\$INST variables at the beginning of this script,
or use --source/--install options, if you want to use other paths!

Number of threads for building: \$THREADS (automatically detected, use --threads=<nbr> to override it).
Full install: \$WITH_ALL (use --with-all option to enable it).
Building OSL: \$WITH_OSL (use --with-osl option to enable it).
Building OpenCOLLADA: \$WITH_OPENCOLLADA (use --with-opencollada option to enable it).
All static linking: \$ALL_STATIC (use --all-static option to enable it).

WARNING: Static build works fine with CMake, but with scons it may be tricky to get a valid Blender build!

Example:
Full install without OpenCOLLADA: --with-all --skip-opencollada

Use --help to show all available options!\""

ARGUMENTS_INFO="\"COMMAND LINE ARGUMENTS:
    -h, --help
        Show this message and exit.

    -s <path>, --source=<path>
        Use a specific path where to store downloaded libraries sources (defaults to '\$SRC').

    -i <path>, --install=<path>
        Use a specific path where to install built libraries (defaults to '\$INST').

    --tmp=<path>
        Use a specific temp path (defaults to '\$TMP').

    -t n, --threads=n
        Use a specific number of threads when building the libraries (auto-detected as '\$THREADS').

    --with-all
        By default, a number of optional and not-so-often needed libraries are not installed.
        This option will try to install them, at the cost of potential conflicts (depending on
        how your package system is set…).
        Note this option also implies all other (more specific) --with-foo options below.

    --with-osl
        Try to install or build the OpenShadingLanguage libraries (and their dependencies).
        Still experimental!

    --with-opencollada
        Build and install the OpenCOLLADA libraries.

    --all-static
        Build libraries as statically as possible, to create static builds of Blender.

    --force-all
        Force the rebuild of all built libraries.

    --force-python
        Force the rebuild of Python.

    --force-numpy
        Force the rebuild of NumPy.

    --force-boost
        Force the rebuild of Boost.

    --force-ocio
        Force the rebuild of OpenColorIO.

    --force-openexr
        Force the rebuild of OpenEXR.

    --force-oiio
        Force the rebuild of OpenImageIO.

    --force-llvm
        Force the rebuild of LLVM.

    --force-osl
        Force the rebuild of OpenShadingLanguage.

    --force-opencollada
        Force the rebuild of OpenCOLLADA.

    --force-ffmpeg
        Force the rebuild of FFMpeg.

    Note about the --force-foo options:
        * They obviously only have an effect if those libraries are built by this script
          (i.e. if there is no available and satisfactory package)!
        * If the “force-rebuilt” library is a dependency of others, it will force the rebuild
          of those libraries too (e.g. --force-boost will also rebuild oiio and osl...).
        * Do not forget --with-osl if you built it and still want it!

    --skip-python
        Unconditionally skip Python installation/building.

    --skip-numpy
        Unconditionally skip NumPy installation/building.

    --skip-boost
        Unconditionally skip Boost installation/building.

    --skip-ocio
        Unconditionally skip OpenColorIO installation/building.

    --skip-openexr
        Unconditionally skip OpenEXR installation/building.

    --skip-oiio
        Unconditionally skip OpenImageIO installation/building.

    --skip-llvm
        Unconditionally skip LLVM installation/building.

    --skip-osl
        Unconditionally skip OpenShadingLanguage installation/building.

    --skip-opencollada
        Unconditionally skip OpenCOLLADA installation/building.

    --skip-ffmpeg
        Unconditionally skip FFMpeg installation/building.\""

##### Main Vars #####

PYTHON_VERSION="3.3.0"
PYTHON_VERSION_MIN="3.3"
PYTHON_SOURCE="http://python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.bz2"
PYTHON_FORCE_REBUILD=false
PYTHON_SKIP=false

NUMPY_VERSION="1.7.0"
NUMPY_VERSION_MIN="1.7"
NUMPY_SOURCE="http://sourceforge.net/projects/numpy/files/NumPy/$NUMPY_VERSION/numpy-$NUMPY_VERSION.tar.gz"
NUMPY_FORCE_REBUILD=false
NUMPY_SKIP=false

BOOST_VERSION="1.51.0"
_boost_version_nodots=`echo "$BOOST_VERSION" | sed -r 's/\./_/g'`
BOOST_SOURCE="http://sourceforge.net/projects/boost/files/boost/$BOOST_VERSION/boost_$_boost_version_nodots.tar.bz2/download"
BOOST_VERSION_MIN="1.49"
BOOST_FORCE_REBUILD=false
BOOST_SKIP=false
_need_boost_ldconfig=false

OCIO_VERSION="1.0.7"
OCIO_SOURCE="https://github.com/imageworks/OpenColorIO/tarball/v$OCIO_VERSION"
OCIO_VERSION_MIN="1.0"
OCIO_FORCE_REBUILD=false
OCIO_SKIP=false

OPENEXR_VERSION="2.0.0"
OPENEXR_SOURCE="http://download.savannah.nongnu.org/releases/openexr/openexr-$OPENEXR_VERSION.tar.gz"
OPENEXR_VERSION_MIN="2.0"
ILMBASE_VERSION="2.0.0"
ILMBASE_SOURCE="http://download.savannah.nongnu.org/releases/openexr/ilmbase-$ILMBASE_VERSION.tar.gz"
OPENEXR_FORCE_REBUILD=false
OPENEXR_SKIP=false
_with_built_openexr=false

OIIO_VERSION="1.1.10"
OIIO_SOURCE="https://github.com/OpenImageIO/oiio/archive/Release-$OIIO_VERSION.tar.gz"
OIIO_VERSION_MIN="1.1"
OIIO_FORCE_REBUILD=false
OIIO_SKIP=false
_need_oiio_ldconfig=false

LLVM_VERSION="3.1"
LLVM_VERSION_MIN="3.0"
LLVM_VERSION_FOUND=""
LLVM_SOURCE="http://llvm.org/releases/$LLVM_VERSION/llvm-$LLVM_VERSION.src.tar.gz"
LLVM_CLANG_SOURCE="http://llvm.org/releases/$LLVM_VERSION/clang-$LLVM_VERSION.src.tar.gz"
LLVM_FORCE_REBUILD=false
LLVM_SKIP=false

# OSL needs to be compiled for now!
OSL_VERSION="1.3.2"
OSL_SOURCE="https://github.com/imageworks/OpenShadingLanguage/archive/Release-$OSL_VERSION.tar.gz"
OSL_FORCE_REBUILD=false
OSL_SKIP=false

# Version??
OPENCOLLADA_VERSION="1.3"
OPENCOLLADA_SOURCE="https://github.com/KhronosGroup/OpenCOLLADA.git"
OPENCOLLADA_FORCE_REBUILD=false
OPENCOLLADA_SKIP=false

FFMPEG_VERSION="1.0"
FFMPEG_SOURCE="http://ffmpeg.org/releases/ffmpeg-$FFMPEG_VERSION.tar.bz2"
FFMPEG_VERSION_MIN="0.7.6"
FFMPEG_FORCE_REBUILD=false
FFMPEG_SKIP=false
_ffmpeg_list_sep=";"

# FFMPEG optional libs.
VORBIS_USE=false
VORBIS_DEV=""
THEORA_USE=false
THEORA_DEV=""
XVID_USE=false
XVID_DEV=""
X264_USE=false
X264_DEV=""
X264_VERSION_MIN=0.118
VPX_USE=false
VPX_VERSION_MIN=0.9.7
VPX_DEV=""
MP3LAME_USE=false
MP3LAME_DEV=""
OPENJPEG_USE=false
OPENJPEG_DEV=""

# Switch to english language, else some things (like check_package_DEB()) won't work!
LANG_BACK=$LANG
LANG=""
export LANG

##### Generic Helpers #####

_echo() {
  if [ "X$1" = "X-n" ]; then
     shift; printf "%s" "$@"
  else
     printf "%s\n" "$@"
  fi
}

ERROR() {
  _echo "$@"
}

INFO() {
  _echo "$@"
}

##### Args Handling #####

# Finish parsing the commandline args.
eval set -- "$ARGS"
while true; do
  case $1 in
    -s|--source)
      SRC="$2"; shift; shift; continue
    ;;
    -i|--install)
      INST="$2"; shift; shift; continue
    ;;
    --tmp)
      TMP="$2"; shift; shift; continue
    ;;
    -t|--threads)
      THREADS="$2"; shift; shift; continue
    ;;
    -h|--help)
      INFO ""
      INFO "USAGE:"
      INFO ""
      INFO "`eval _echo "$COMMON_INFO"`"
      INFO ""
      INFO "`eval _echo "$ARGUMENTS_INFO"`"
      INFO ""
      exit 0
    ;;
    --with-all)
      WITH_ALL=true; shift; continue
    ;;
    --with-osl)
      WITH_OSL=true; shift; continue
    ;;
    --with-opencollada)
      WITH_OPENCOLLADA=true; shift; continue
    ;;
    --all-static)
      ALL_STATIC=true; shift; continue
    ;;
    --force-all)
      PYTHON_FORCE_REBUILD=true
      NUMPY_FORCE_REBUILD=true
      BOOST_FORCE_REBUILD=true
      OCIO_FORCE_REBUILD=true
      OIIO_FORCE_REBUILD=true
      LLVM_FORCE_REBUILD=true
      OSL_FORCE_REBUILD=true
      OPENCOLLADA_FORCE_REBUILD=true
      FFMPEG_FORCE_REBUILD=true
      shift; continue
    ;;
    --force-python)
      PYTHON_FORCE_REBUILD=true
      NUMPY_FORCE_REBUILD=true
      shift; continue
    ;;
    --force-numpy)
      NUMPY_FORCE_REBUILD=true; shift; continue
    ;;
    --force-boost)
      BOOST_FORCE_REBUILD=true; shift; continue
    ;;
    --force-ocio)
      OCIO_FORCE_REBUILD=true; shift; continue
    ;;
    --force-openexr)
      OPENEXR_FORCE_REBUILD=true; shift; continue
    ;;
    --force-oiio)
      OIIO_FORCE_REBUILD=true
      shift; continue
    ;;
    --force-llvm)
      LLVM_FORCE_REBUILD=true
      OSL_FORCE_REBUILD=true
      shift; continue
    ;;
    --force-osl)
      OSL_FORCE_REBUILD=true; shift; continue
    ;;
    --force-opencollada)
      OPENCOLLADA_FORCE_REBUILD=true; shift; continue
    ;;
    --force-ffmpeg)
      FFMPEG_FORCE_REBUILD=true; shift; continue
    ;;
    --skip-python)
      PYTHON_SKIP=true; shift; continue
    ;;
    --skip-numpy)
      NUMPY_SKIP=true; shift; continue
    ;;
    --skip-boost)
      BOOST_SKIP=true; shift; continue
    ;;
    --skip-ocio)
      OCIO_SKIP=true; shift; continue
    ;;
    --skip-openexr)
      OPENEXR_SKIP=true; shift; continue
    ;;
    --skip-oiio)
      OIIO_SKIP=true; shift; continue
    ;;
    --skip-llvm)
      LLVM_SKIP=true; shift; continue
    ;;
    --skip-osl)
      OSL_SKIP=true; shift; continue
    ;;
    --skip-opencollada)
      OPENCOLLADA_SKIP=true; shift; continue
    ;;
    --skip-ffmpeg)
      FFMPEG_SKIP=true; shift; continue
    ;;
    --)
      # no more arguments to parse
      break
    ;;
    *)
      INFO ""
      INFO "Wrong parameter! Usage:"
      INFO ""
      INFO "`eval _echo "$COMMON_INFO"`"
      INFO ""
      exit 1
    ;;
  esac
done

if $WITH_ALL; then
  WITH_OSL=true
  WITH_OPENCOLLADA=true
fi

##### Generic Helpers #####

# Return 0 if $1 = $2 (i.e. 1.01.0 = 1.1, but 1.1.1 != 1.1), else 1.
# $1 and $2 should be version numbers made of numbers only.
version_eq() {
  backIFS=$IFS
  IFS='.'

  # Split both version numbers into their numeric elements.
  arr1=( $1 )
  arr2=( $2 )

  ret=1

  count1=${#arr1[@]}
  count2=${#arr2[@]}
  if [ $count2 -ge $count1 ]; then
    _t=$count1
    count1=$count2
    count2=$_t
    arr1=( $2 )
    arr2=( $1 )
  fi

  ret=0
  for (( i=0; $i < $count2; i++ ))
  do
    if [ $(( 10#${arr1[$i]} )) -ne $(( 10#${arr2[$i]} )) ]; then
      ret=1
      break
    fi
  done

  for (( i=$count2; $i < $count1; i++ ))
  do
    if [ $(( 10#${arr1[$i]} )) -ne 0 ]; then
      ret=1
      break
    fi
  done

  IFS=$backIFS
  return $ret
}

# Return 0 if $1 >= $2, else 1.
# $1 and $2 should be version numbers made of numbers only.
version_ge() {
  version_eq $1 $2
  if [ $? -eq 1 -a $(_echo "$1" "$2" | sort --version-sort | head --lines=1) = "$1" ]; then
    return 1
  else
    return 0
  fi
}

# Return 0 if $1 is into $2 (e.g. 3.3.2 is into 3.3, but not 3.3.0 or 3.3.5), else 1.
# $1 and $2 should be version numbers made of numbers only.
# $1 should be at least as long as $2!
version_match() {
  backIFS=$IFS
  IFS='.'

  # Split both version numbers into their numeric elements.
  arr1=( $1 )
  arr2=( $2 )

  ret=1

  count1=${#arr1[@]}
  count2=${#arr2[@]}
  if [ $count1 -ge $count2 ]; then
    ret=0
    for (( i=0; $i < $count2; i++ ))
    do
      if [ $(( 10#${arr1[$i]} )) -ne $(( 10#${arr2[$i]} )) ]; then
        ret=1
        break
      fi
    done
  fi

  IFS=$backIFS
  return $ret
}

##### Generic compile helpers #####
prepare_opt() {
  INFO "Ensuring $INST exists and is writable by us"
  if [ ! -d  $INST ]; then
    sudo mkdir -p $INST
  fi

  if [ ! -w $INST ]; then
    sudo chown $USER $INST
    sudo chmod 775 $INST
  fi
}

# Check whether the current package needs to be recompiled, based on a dummy file containing a magic number in its name...
magic_compile_check() {
  if [ -f $INST/.$1-magiccheck-$2 ]; then
    return 0
  else
    return 1
  fi
}

magic_compile_set() {
  rm -f $INST/.$1-magiccheck-*
  touch $INST/.$1-magiccheck-$2
}

# Note: should clean nicely in $INST, but not in $SRC, when we switch to a new version of a lib...
_clean() {
  rm -rf `readlink -f $_inst_shortcut`
  rm -rf $_src
  rm -rf $_inst
  rm -rf $_inst_shortcut
}

_create_inst_shortcut() {
  rm -f $_inst_shortcut
  ln -s $_inst $_inst_shortcut
}

#### Build Python ####
_init_python() {
  _src=$SRC/Python-$PYTHON_VERSION
  _inst=$INST/python-$PYTHON_VERSION
  _inst_shortcut=$INST/python-3.3
}

clean_Python() {
  clean_Numpy
  _init_python
  _clean
}

compile_Python() {
  # To be changed each time we make edits that would modify the compiled result!
  py_magic=0
  _init_python

  # Clean install if needed!
  magic_compile_check python-$PYTHON_VERSION $py_magic
  if [ $? -eq 1 -o $PYTHON_FORCE_REBUILD == true ]; then
    clean_Python
  fi

  if [ ! -d $_inst ]; then
    INFO "Building Python-$PYTHON_VERSION"

    prepare_opt

    if [ ! -d $_src ]; then
      mkdir -p $SRC
      wget -c $PYTHON_SOURCE -O $_src.tar.bz2

      INFO "Unpacking Python-$PYTHON_VERSION"
      tar -C $SRC -xf $_src.tar.bz2
    fi

    cd $_src

    ./configure --prefix=$_inst --enable-ipv6 \
        --enable-loadable-sqlite-extensions --with-dbmliborder=bdb \
        --with-computed-gotos --with-pymalloc

    make -j$THREADS && make install
    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "Python--$PYTHON_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set python-$PYTHON_VERSION $py_magic

    cd $CWD
    INFO "Done compiling Python-$PYTHON_VERSION!"
  else
    INFO "Own Python-$PYTHON_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-python option."
  fi
}

##### Build Numpy #####
_init_numpy() {
  _src=$SRC/numpy-$NUMPY_VERSION
  _inst=$INST/numpy-$NUMPY_VERSION
  _python=$INST/python-$PYTHON_VERSION
  _site=lib/python3.3/site-packages
  _inst_shortcut=$_python/$_site/numpy
}

clean_Numpy() {
  _init_numpy
  _clean
}

compile_Numpy() {
  # To be changed each time we make edits that would modify the compiled result!
  py_magic=0
  _init_numpy

  # Clean install if needed!
  magic_compile_check numpy-$NUMPY_VERSION $py_magic
  if [ $? -eq 1 -o $NUMPY_FORCE_REBUILD == true ]; then
    clean_Numpy
  fi

  if [ ! -d $_inst ]; then
    INFO "Building Numpy-$NUMPY_VERSION"

    prepare_opt

    if [ ! -d $_src ]; then
      mkdir -p $SRC
      wget -c $NUMPY_SOURCE -O $_src.tar.gz

      INFO "Unpacking Numpy-$NUMPY_VERSION"
      tar -C $SRC -xf $_src.tar.gz
    fi

    cd $_src

    $_python/bin/python3 setup.py install --prefix=$_inst

    if [ -d $_inst ]; then
      # Can't use _create_inst_shortcut here...
      rm -f $_inst_shortcut
      ln -s $_inst/$_site/numpy $_inst_shortcut
    else
      ERROR "Numpy-$NUMPY_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set numpy-$NUMPY_VERSION $py_magic

    cd $CWD
    INFO "Done compiling Numpy-$NUMPY_VERSION!"
  else
    INFO "Own Numpy-$NUMPY_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-numpy option."
  fi
}

#### Build Boost ####
_init_boost() {
  _src=$SRC/boost-$BOOST_VERSION
  _inst=$INST/boost-$BOOST_VERSION
  _inst_shortcut=$INST/boost
}

clean_Boost() {
  _init_boost
  _clean
}

compile_Boost() {
  # To be changed each time we make edits that would modify the compiled result!
  boost_magic=7

  _init_boost

  # Clean install if needed!
  magic_compile_check boost-$BOOST_VERSION $boost_magic
  if [ $? -eq 1 -o $BOOST_FORCE_REBUILD == true ]; then
    clean_Boost
  fi

  if [ ! -d $_inst ]; then
    INFO "Building Boost-$BOOST_VERSION"

    # Rebuild dependecies as well!
    OIIO_FORCE_REBUILD=true
    OSL_FORCE_REBUILD=true

    prepare_opt

    if [ ! -d $_src ]; then
      INFO "Downloading Boost-$BOOST_VERSION"
      mkdir -p $SRC
      wget -c $BOOST_SOURCE -O $_src.tar.bz2
      tar -C $SRC --transform "s,(.*/?)boost_1_[^/]+(.*),\1boost-$BOOST_VERSION\2,x" -xf $_src.tar.bz2
    fi

    cd $_src
    if [ ! -f $_src/b2 ]; then
      ./bootstrap.sh
    fi
    ./b2 -j$THREADS -a --with-system --with-filesystem --with-thread --with-regex --with-locale --with-date_time \
         --prefix=$_inst --disable-icu boost.locale.icu=off install
    ./b2 --clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "Boost-$BOOST_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set boost-$BOOST_VERSION $boost_magic

    cd $CWD
    INFO "Done compiling Boost-$BOOST_VERSION!"
  else
    INFO "Own Boost-$BOOST_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-boost option."
  fi

  # Just always run it, much simpler this way!
  _need_boost_ldconfig=true
}

#### Build OCIO ####
_init_ocio() {
  _src=$SRC/OpenColorIO-$OCIO_VERSION
  _inst=$INST/ocio-$OCIO_VERSION
  _inst_shortcut=$INST/ocio
}

clean_OCIO() {
  _init_ocio
  _clean
}

compile_OCIO() {
  # To be changed each time we make edits that would modify the compiled result!
  ocio_magic=1
  _init_ocio

  # Clean install if needed!
  magic_compile_check ocio-$OCIO_VERSION $ocio_magic
  if [ $? -eq 1 -o $OCIO_FORCE_REBUILD == true ]; then
    clean_OCIO
  fi

  if [ ! -d $_inst ]; then
    INFO "Building OpenColorIO-$OCIO_VERSION"

    prepare_opt

    if [ ! -d $_src ]; then
      INFO "Downloading OpenColorIO-$OCIO_VERSION"
      mkdir -p $SRC
      wget -c $OCIO_SOURCE -O $_src.tar.gz

      INFO "Unpacking OpenColorIO-$OCIO_VERSION"
      tar -C $SRC --transform "s,(.*/?)imageworks-OpenColorIO[^/]*(.*),\1OpenColorIO-$OCIO_VERSION\2,x" \
          -xf $_src.tar.gz
    fi

    cd $_src
    # Always refresh the whole build!
    if [ -d build ]; then
      rm -rf build
    fi    
    mkdir build
    cd build

    if file /bin/cp | grep -q '32-bit'; then
      cflags="-fPIC -m32 -march=i686"
    else
      cflags="-fPIC"
    fi

    cmake -D CMAKE_BUILD_TYPE=Release \
          -D CMAKE_PREFIX_PATH=$_inst \
          -D CMAKE_INSTALL_PREFIX=$_inst \
          -D CMAKE_CXX_FLAGS="$cflags" \
          -D CMAKE_EXE_LINKER_FLAGS="-lgcc_s -lgcc" \
          -D OCIO_BUILD_APPS=OFF \
          -D OCIO_BUILD_PYGLUE=OFF \
          ..

    make -j$THREADS && make install

    # Force linking against static libs
    rm -f $_inst/lib/*.so*

    # Additional depencencies
    cp ext/dist/lib/libtinyxml.a $_inst/lib
    cp ext/dist/lib/libyaml-cpp.a $_inst/lib

    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "OpenColorIO-$OCIO_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set ocio-$OCIO_VERSION $ocio_magic

    cd $CWD
    INFO "Done compiling OpenColorIO-$OCIO_VERSION!"
  else
    INFO "Own OpenColorIO-$OCIO_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-ocio option."
  fi
}

#### Build ILMBase ####
_init_ilmbase() {
  _src=$SRC/ILMBase-$ILMBASE_VERSION
  _inst=$TMP/ilmbase-$ILMBASE_VERSION
  _inst_shortcut=$TMP/ilmbase
}

clean_ILMBASE() {
  _init_ilmbase
  _clean
}

compile_ILMBASE() {
  # To be changed each time we make edits that would modify the compiled result!
  ilmbase_magic=5
  _init_ilmbase

  # Clean install if needed!
  magic_compile_check ilmbase-$ILMBASE_VERSION $ilmbase_magic

  if [ $? -eq 1 -o $OPENEXR_FORCE_REBUILD == true ]; then
    clean_ILMBASE
    rm -rf $_openexr_inst
  fi

  if [ ! -d $_openexr_inst ]; then
    INFO "Building ILMBase-$ILMBASE_VERSION"

    # Rebuild dependecies as well!
    OPENEXR_FORCE_REBUILD=true

    prepare_opt

    if [ ! -d $_src ]; then
      INFO "Downloading ILMBase-$ILMBASE_VERSION"
      mkdir -p $SRC
      wget -c $ILMBASE_SOURCE -O $_src.tar.gz

      INFO "Unpacking ILMBase-$ILMBASE_VERSION"
      tar -C $SRC --transform "s,(.*/?)ilmbase-[^/]*(.*),\1ILMBase-$ILMBASE_VERSION\2,x" \
          -xf $_src.tar.gz

      cd $_src

      # XXX Ugly patching hack!
      cat << EOF | patch -p1
--- a/Half/CMakeLists.txt
+++ b/Half/CMakeLists.txt
@@ -47,6 +47,7 @@
 
 INSTALL ( FILES 
   half.h
+  halfExport.h
   halfFunction.h
   halfLimits.h
   DESTINATION
EOF

      cd $CWD

    fi

    cd $_src
    # Always refresh the whole build!
    if [ -d build ]; then
      rm -rf build
    fi    
    mkdir build
    cd build

    cmake_d="-D CMAKE_BUILD_TYPE=Release"
    cmake_d="$cmake_d -D CMAKE_PREFIX_PATH=$_inst"
    cmake_d="$cmake_d -D CMAKE_INSTALL_PREFIX=$_inst"

    if file /bin/cp | grep -q '32-bit'; then
      cflags="-fPIC -m32 -march=i686"
    else
      cflags="-fPIC"
    fi

    cmake $cmake_d -D CMAKE_CXX_FLAGS="$cflags" -D CMAKE_EXE_LINKER_FLAGS="-lgcc_s -lgcc" ..

    make -j$THREADS && make install

    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "ILMBase-$ILMBASE_VERSION failed to compile, exiting"
      exit 1
    fi
  else
    INFO "Own ILMBase-$ILMBASE_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib (and openexr), use the --force-openexr option."
  fi

  magic_compile_set ilmbase-$ILMBASE_VERSION $ilmbase_magic

  cd $CWD
  INFO "Done compiling ILMBase-$ILMBASE_VERSION!"
}

#### Build OpenEXR ####
_init_openexr() {
  _src=$SRC/OpenEXR-$OPENEXR_VERSION
  _inst=$_openexr_inst
  _inst_shortcut=$INST/openexr
}

clean_OPENEXR() {
  clean_ILMBASE
  _init_openexr
  _clean
}

compile_OPENEXR() {
  # To be changed each time we make edits that would modify the compiled result!
  openexr_magic=10

  # Clean install if needed!
  magic_compile_check openexr-$OPENEXR_VERSION $openexr_magic
  if [ $? -eq 1 -o $OPENEXR_FORCE_REBUILD == true ]; then
    clean_OPENEXR
  fi

  _openexr_inst=$INST/openexr-$OPENEXR_VERSION
  compile_ILMBASE
  _ilmbase_inst=$_inst_shortcut
  _init_openexr

  if [ ! -d $_inst ]; then
    INFO "Building OpenEXR-$OPENEXR_VERSION"

    # Rebuild dependecies as well!
    OIIO_FORCE_REBUILD=true
    OSL_FORCE_REBUILD=true

    prepare_opt

    if [ ! -d $_src ]; then
      INFO "Downloading OpenEXR-$OPENEXR_VERSION"
      mkdir -p $SRC
      wget -c $OPENEXR_SOURCE -O $_src.tar.gz

      INFO "Unpacking OpenEXR-$OPENEXR_VERSION"
      tar -C $SRC --transform "s,(.*/?)openexr[^/]*(.*),\1OpenEXR-$OPENEXR_VERSION\2,x" \
          -xf $_src.tar.gz

      cd $_src

      # XXX Ugly patching hack!
      cat << EOF | patch -p1
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -42,7 +42,7 @@
 ADD_SUBDIRECTORY ( exrmakepreview )
 ADD_SUBDIRECTORY ( exrenvmap )
 ADD_SUBDIRECTORY ( exrmultiview )
-ADD_SUBDIRECTORY ( exr2aces )
+#ADD_SUBDIRECTORY ( exr2aces )
 ADD_SUBDIRECTORY ( exrmultipart )
 
 ##########################
@@ -52,11 +52,11 @@
 # Documentation
 INSTALL ( FILES
   doc/TechnicalIntroduction.pdf
-  doc/TechnicalIntroduction_2.0.pdf
+#  doc/TechnicalIntroduction_2.0.pdf
   doc/ReadingAndWritingImageFiles.pdf
   doc/OpenEXRFileLayout.pdf
-  doc/OpenEXRFileLayout_2.0.pdf
-  doc/ReadingAndWritingImageFiles_2.0.pdf
+#  doc/OpenEXRFileLayout_2.0.pdf
+#  doc/ReadingAndWritingImageFiles_2.0.pdf
   doc/MultiViewOpenEXR.pdf
   DESTINATION
   ${CMAKE_INSTALL_PREFIX}/share/doc/OpenEXR-2.0.0
--- a/IlmImfFuzzTest/CMakeLists.txt
+++ b/IlmImfFuzzTest/CMakeLists.txt
@@ -4,7 +4,9 @@
   fuzzFile.cpp
   main.cpp
   testFuzzScanLines.cpp
+  testFuzzDeepScanLines.cpp
   testFuzzTiles.cpp
+  testFuzzDeepTiles.cpp
   )
 
 TARGET_LINK_LIBRARIES ( IlmImfFuzzTest IlmImf Iex Imath Half IlmThread ${PTHREAD_LIB} ${Z_LIB})
--- a/IlmImfTest/CMakeLists.txt
+++ b/IlmImfTest/CMakeLists.txt
@@ -19,22 +19,26 @@
   testCustomAttributes.cpp
   testDeepScanLineBasic.cpp
   testDeepScanLineHuge.cpp
+  testDeepScanLineMultipleRead.cpp
   testDeepTiledBasic.cpp
   testExistingStreams.cpp
+  testFutureProofing.cpp
   testHuf.cpp
   testInputPart.cpp
   testIsComplete.cpp
   testLineOrder.cpp
   testLut.cpp
   testMagic.cpp
   testMultiPartApi.cpp
   testMultiPartFileMixingBasic.cpp
   testMultiPartSharedAttributes.cpp
   testMultiPartThreading.cpp
   testMultiScanlinePartThreading.cpp
   testMultiTiledPartThreading.cpp
   testMultiView.cpp
   testNativeFormat.cpp
+  testOptimized.cpp
+  testPartHelper.cpp
   testPreviewImage.cpp
   testRgba.cpp
   testRgbaThreading.cpp
--- a/IlmImf/CMakeLists.txt
+++ b/IlmImf/CMakeLists.txt
@@ -153,18 +153,18 @@
   ImfCompositeDeepScanLine.cpp
 )
 
-ADD_LIBRARY ( IlmImf STATIC
-  \${ILMIMF_SRCS}
-)
-
-# TARGET_LINK_LIBRARIES ( IlmImf)
-
-ADD_DEPENDENCIES ( IlmImf b44ExpLogTable )
+ADD_LIBRARY ( IlmImf STATIC \${ILMIMF_SRCS} )
+ADD_DEPENDENCIES ( IlmImf b44ExpLogTable )
+
+ADD_LIBRARY ( IlmImf_dyn SHARED \${ILMIMF_SRCS} )
+SET_TARGET_PROPERTIES ( IlmImf_dyn PROPERTIES OUTPUT_NAME IlmImf)
+ADD_DEPENDENCIES ( IlmImf_dyn b44ExpLogTable )
+TARGET_LINK_LIBRARIES ( IlmImf_dyn Iex Imath Half IlmThread \${Z_LIB} \${PTHREAD_LIB} )
 
 # Libraries
 
 INSTALL ( TARGETS
-  IlmImf
+  IlmImf IlmImf_dyn
   DESTINATION
   \${CMAKE_INSTALL_PREFIX}/lib
 )
@@ -168,6 +167,7 @@
 INSTALL ( FILES
   ${CMAKE_SOURCE_DIR}/config/OpenEXRConfig.h
   ImfForward.h
+  ImfNamespace.h
   ImfExport.h
   ImfAttribute.h
   ImfBoxAttribute.h
EOF

      cd $CWD

    fi

    cd $_src
    # Always refresh the whole build!
    if [ -d build ]; then
      rm -rf build
    fi    
    mkdir build
    cd build

    cmake_d="-D CMAKE_BUILD_TYPE=Release"
    cmake_d="$cmake_d -D CMAKE_PREFIX_PATH=$_inst"
    cmake_d="$cmake_d -D CMAKE_INSTALL_PREFIX=$_inst"
    cmake_d="$cmake_d -D ILMBASE_PACKAGE_PREFIX=$_ilmbase_inst"

    if file /bin/cp | grep -q '32-bit'; then
      cflags="-fPIC -m32 -march=i686"
    else
      cflags="-fPIC"
    fi

    cmake $cmake_d -D CMAKE_CXX_FLAGS="$cflags" -D CMAKE_EXE_LINKER_FLAGS="-lgcc_s -lgcc" ..

    make -j$THREADS && make install

    # Force linking against static libs
#    rm -f $_inst/lib/*.so*

    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
      # Copy ilmbase files here (blender expects same dir for ilmbase and openexr :/).
      cp -Lrn $_ilmbase_inst/* $_inst_shortcut
    else
      ERROR "OpenEXR-$OPENEXR_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set openexr-$OPENEXR_VERSION $openexr_magic

    cd $CWD
    INFO "Done compiling OpenEXR-$OPENEXR_VERSION!"
  else
    INFO "Own OpenEXR-$OPENEXR_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-openexr option."
  fi

  _with_built_openexr=true

  # Just always run it, much simpler this way!
  _need_openexr_ldconfig=true
}

#### Build OIIO ####
_init_oiio() {
  _src=$SRC/OpenImageIO-$OIIO_VERSION
  _inst=$INST/oiio-$OIIO_VERSION
  _inst_shortcut=$INST/oiio
}

clean_OIIO() {
  _init_oiio
  _clean
}

compile_OIIO() {
  # To be changed each time we make edits that would modify the compiled result!
  oiio_magic=12
  _init_oiio

  # Clean install if needed!
  magic_compile_check oiio-$OIIO_VERSION $oiio_magic
  if [ $? -eq 1 -o $OIIO_FORCE_REBUILD == true ]; then
    clean_OIIO
  fi

  if [ ! -d $_inst ]; then
    INFO "Building OpenImageIO-$OIIO_VERSION"

    # Rebuild dependecies as well!
    OSL_FORCE_REBUILD=true

    prepare_opt

    if [ ! -d $_src ]; then
      mkdir -p $SRC
      wget -c $OIIO_SOURCE -O "$_src.tar.gz"

      INFO "Unpacking OpenImageIO-$OIIO_VERSION"
      tar -C $SRC --transform "s,(.*/?)oiio-Release-[^/]*(.*),\1OpenImageIO-$OIIO_VERSION\2,x" \
          -xf $_src.tar.gz

      cd $_src

      # XXX Ugly patching hack!
      cat << EOF | patch -p1
--- a/src/libOpenImageIO/CMakeLists.txt
+++ b/src/libOpenImageIO/CMakeLists.txt
@@ -289,12 +289,12 @@
 
 add_executable (imagebuf_test imagebuf_test.cpp)
-link_ilmbase (imagebuf_test)
 target_link_libraries (imagebuf_test OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (imagebuf_test)
 add_test (unit_imagebuf imagebuf_test)
 
 add_executable (imagebufalgo_test imagebufalgo_test.cpp)
-link_ilmbase (imagebufalgo_test)
 target_link_libraries (imagebufalgo_test OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (imagebufalgo_test)
 add_test (unit_imagebufalgo imagebufalgo_test)
 
 
@@ -340,5 +340,6 @@
 
 add_executable (imagespeed_test imagespeed_test.cpp)
 target_link_libraries (imagespeed_test OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (imagespeed_test)
 #add_test (unit_hash hash_test)
 
--- a/src/iconvert/CMakeLists.txt
+++ b/src/iconvert/CMakeLists.txt
@@ -1,6 +1,6 @@
 set (iconvert_srcs iconvert.cpp)
 add_executable (iconvert \${iconvert_srcs})
-link_ilmbase (iconvert)
 target_link_libraries (iconvert OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (iconvert)
 oiio_install_targets (iconvert)
 
--- a/src/idiff/CMakeLists.txt
+++ b/src/idiff/CMakeLists.txt
@@ -1,6 +1,6 @@
 set (idiff_srcs idiff.cpp)
 add_executable (idiff \${idiff_srcs})
-link_ilmbase (idiff)
 target_link_libraries (idiff OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (idiff)
 oiio_install_targets (idiff)
 
--- a/src/igrep/CMakeLists.txt
+++ b/src/igrep/CMakeLists.txt
@@ -1,6 +1,6 @@
 set (igrep_srcs igrep.cpp)
 add_executable (igrep \${igrep_srcs})
-link_ilmbase (igrep)
 target_link_libraries (igrep OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (igrep)
 oiio_install_targets (igrep)
 
--- a/src/iinfo/CMakeLists.txt
+++ b/src/iinfo/CMakeLists.txt
@@ -3,7 +3,7 @@
 if (MSVC)
     set_target_properties (OpenImageIO PROPERTIES LINK_FLAGS psapi.lib)
 endif (MSVC)
-link_ilmbase (iinfo)
 target_link_libraries (iinfo OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (iinfo)
 oiio_install_targets (iinfo)
 
--- a/src/maketx/CMakeLists.txt
+++ b/src/maketx/CMakeLists.txt
@@ -1,6 +1,6 @@
 set (maketx_srcs maketx.cpp)
 add_executable (maketx \${maketx_srcs})
-link_ilmbase (maketx)
 target_link_libraries (maketx OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (maketx)
 oiio_install_targets (maketx)
 
--- a/src/oiiotool/CMakeLists.txt
+++ b/src/oiiotool/CMakeLists.txt
@@ -1,6 +1,6 @@
 set (oiiotool_srcs oiiotool.cpp diff.cpp imagerec.cpp printinfo.cpp)
 add_executable (oiiotool \${oiiotool_srcs})
-link_ilmbase (oiiotool)
 target_link_libraries (oiiotool OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (oiiotool)
 oiio_install_targets (oiiotool)
 
--- a/src/testtex/CMakeLists.txt
+++ b/src/testtex/CMakeLists.txt
@@ -1,5 +1,5 @@
 set (testtex_srcs testtex.cpp)
 add_executable (testtex \${testtex_srcs})
-link_ilmbase (testtex)
 target_link_libraries (testtex OpenImageIO \${Boost_LIBRARIES} \${CMAKE_DL_LIBS})
+link_ilmbase (testtex)
 
--- a/src/cmake/modules/FindIlmBase.cmake
+++ b/src/cmake/modules/FindIlmBase.cmake
@@ -109,11 +109,13 @@
 # Generic search paths
 set (IlmBase_generic_include_paths
   /usr/include
+  /usr/include/\${CMAKE_LIBRARY_ARCHITECTURE}
   /usr/local/include
   /sw/include
   /opt/local/include)
 set (IlmBase_generic_library_paths
   /usr/lib
+  /usr/lib/\${CMAKE_LIBRARY_ARCHITECTURE}
   /usr/local/lib
   /sw/lib
   /opt/local/lib)
--- a/src/cmake/modules/FindOpenEXR.cmake
+++ b/src/cmake/modules/FindOpenEXR.cmake
@@ -105,11 +105,13 @@
 # Generic search paths
 set (OpenEXR_generic_include_paths
   /usr/include
+  /usr/include/\${CMAKE_LIBRARY_ARCHITECTURE}
   /usr/local/include
   /sw/include
   /opt/local/include)
 set (OpenEXR_generic_library_paths
   /usr/lib
+  /usr/lib/\${CMAKE_LIBRARY_ARCHITECTURE}
   /usr/local/lib
   /sw/lib
   /opt/local/lib)
--- a/src/libutil/tbb_misc.cpp
+++ b/src/libutil/tbb_misc.cpp
@@ -44,7 +44,8 @@
 
 using namespace std;
 
-#include "tbb/tbb_machine.h"
+//#include "tbb/tbb_machine.h"
+#include "tbb/tbb_assert_impl.h"
 
 namespace tbb {
 
EOF

      cd $CWD

    fi

    cd $_src
    # Always refresh the whole build!
    if [ -d build ]; then
      rm -rf build
    fi    
    mkdir build
    cd build

    cmake_d="-D CMAKE_BUILD_TYPE=Release"
    cmake_d="$cmake_d -D CMAKE_PREFIX_PATH=$_inst"
    cmake_d="$cmake_d -D CMAKE_INSTALL_PREFIX=$_inst"
    cmake_d="$cmake_d -D BUILDSTATIC=OFF"

    if [ $_with_built_openexr == true ]; then
      cmake_d="$cmake_d -D ILMBASE_HOME=$INST/openexr"
      cmake_d="$cmake_d -D ILMBASE_VERSION=$ILMBASE_VERSION"
      cmake_d="$cmake_d -D OPENEXR_HOME=$INST/openexr"
    fi

    # Optional tests and cmd tools
    cmake_d="$cmake_d -D USE_QT=OFF"
    cmake_d="$cmake_d -D USE_PYTHON=OFF"
    cmake_d="$cmake_d -D BUILD_TESTING=OFF"
    #cmake_d="$cmake_d -D CMAKE_EXPORT_COMPILE_COMMANDS=ON"
    #cmake_d="$cmake_d -D CMAKE_VERBOSE_MAKEFILE=ON"

    # linking statically could give issues on Debian/Ubuntu (and probably other distros
    # which doesn't like static linking) when linking shared oiio library due to missing
    # text symbols (static libs should be compiled with -fPIC)
    # cmake_d="$cmake_d -D LINKSTATIC=ON"

    if [ -d $INST/boost ]; then
      cmake_d="$cmake_d -D BOOST_ROOT=$INST/boost -D Boost_NO_SYSTEM_PATHS=ON"
      # XXX Does not work (looks like static boost are built without fPIC :/ ).
      #if $ALL_STATIC; then
        #cmake_d="$cmake_d -D Boost_USE_STATIC_LIBS=ON"
      #fi
    fi

    # Looks like we do not need ocio in oiio for now...
#    if [ -d $INST/ocio ]; then
#      cmake_d="$cmake_d -D OCIO_PATH=$INST/ocio"
#    fi
    cmake_d="$cmake_d -D USE_OCIO=OFF"

    if file /bin/cp | grep -q '32-bit'; then
      cflags="-fPIC -m32 -march=i686"
    else
      cflags="-fPIC"
    fi

    cmake $cmake_d -D CMAKE_CXX_FLAGS="$cflags" -D CMAKE_EXE_LINKER_FLAGS="-lgcc_s -lgcc" ../src

    make -j$THREADS && make install
    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "OpenImageIO-$OIIO_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set oiio-$OIIO_VERSION $oiio_magic

    cd $CWD
    INFO "Done compiling OpenImageIO-$OIIO_VERSION!"
  else
    INFO "Own OpenImageIO-$OIIO_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-oiio option."
  fi

  # Just always run it, much simpler this way!
  _need_oiio_ldconfig=true
}

#### Build LLVM ####
_init_llvm() {
  _src=$SRC/LLVM-$LLVM_VERSION
  _src_clang=$SRC/CLANG-$LLVM_VERSION
  _inst=$INST/llvm-$LLVM_VERSION
  _inst_shortcut=$INST/llvm
}

clean_LLVM() {
  _init_llvm
  _clean
}

compile_LLVM() {
  # To be changed each time we make edits that would modify the compiled result!
  llvm_magic=1
  _init_llvm

  # Clean install if needed!
  magic_compile_check llvm-$LLVM_VERSION $llvm_magic
  if [ $? -eq 1 -o $LLVM_FORCE_REBUILD == true ]; then
    clean_LLVM
  fi

  if [ ! -d $_inst ]; then
    INFO "Building LLVM-$LLVM_VERSION (CLANG included!)"

    prepare_opt

    if [ ! -d $_src -o true ]; then
      mkdir -p $SRC
      wget -c $LLVM_SOURCE -O "$_src.tar.gz"
      wget -c $LLVM_CLANG_SOURCE -O "$_src_clang.tar.gz"

      INFO "Unpacking LLVM-$LLVM_VERSION"
      tar -C $SRC --transform "s,([^/]*/?)llvm-[^/]*(.*),\1LLVM-$LLVM_VERSION\2,x" \
          -xf $_src.tar.gz
      INFO "Unpacking CLANG-$LLVM_VERSION to $_src/tools/clang"
      tar -C $_src/tools \
          --transform "s,([^/]*/?)clang-[^/]*(.*),\1clang\2,x" \
          -xf $_src_clang.tar.gz

      cd $_src

      # XXX Ugly patching hack!
      cat << EOF | patch -p1
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -13,7 +13,7 @@
 set(LLVM_VERSION_MAJOR 3)
 set(LLVM_VERSION_MINOR 1)
 
-set(PACKAGE_VERSION "\${LLVM_VERSION_MAJOR}.\${LLVM_VERSION_MINOR}svn")
+set(PACKAGE_VERSION "\${LLVM_VERSION_MAJOR}.\${LLVM_VERSION_MINOR}")
 
 set_property(GLOBAL PROPERTY USE_FOLDERS ON)
 
EOF

      cd $CWD

    fi

    cd $_src

    # Always refresh the whole build!
    if [ -d build ]; then
      rm -rf build
    fi
    mkdir build
    cd build

    cmake_d="-D CMAKE_BUILD_TYPE=Release"
    cmake_d="$cmake_d -D CMAKE_INSTALL_PREFIX=$_inst"
    cmake_d="$cmake_d -D LLVM_ENABLE_FFI=ON"
    cmake_d="$cmake_d -D LLVM_TARGETS_TO_BUILD=X86"

    if [ -d $_FFI_INCLUDE_DIR ]; then
      cmake_d="$cmake_d -D FFI_INCLUDE_DIR=$_FFI_INCLUDE_DIR"
    fi

    cmake $cmake_d ..

    make -j$THREADS && make install
    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "LLVM-$LLVM_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set llvm-$LLVM_VERSION $llvm_magic

    # Rebuild dependecies as well!
    OSL_FORCE_REBUILD=true

    cd $CWD
    INFO "Done compiling LLVM-$LLVM_VERSION (CLANG included)!"
  else
    INFO "Own LLVM-$LLVM_VERSION (CLANG included) is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-llvm option."
  fi
}

#### Build OSL ####
_init_osl() {
  _src=$SRC/OpenShadingLanguage-$OSL_VERSION
  _inst=$INST/osl-$OSL_VERSION
  _inst_shortcut=$INST/osl
}

clean_OSL() {
  _init_osl
  _clean
}

compile_OSL() {
  # To be changed each time we make edits that would modify the compiled result!
  osl_magic=10
  _init_osl

  # Clean install if needed!
  magic_compile_check osl-$OSL_VERSION $osl_magic
  if [ $? -eq 1 -o $OSL_FORCE_REBUILD == true ]; then
    clean_OSL
  fi

  if [ ! -d $_inst ]; then
    INFO "Building OpenShadingLanguage-$OSL_VERSION"

    prepare_opt

    if [ ! -d $_src ]; then
      mkdir -p $SRC

      wget -c $OSL_SOURCE -O "$_src.tar.gz"

      INFO "Unpacking OpenShadingLanguage-$OSL_VERSION"
      tar -C $SRC --transform "s,(.*/?)OpenShadingLanguage-[^/]*(.*),\1OpenShadingLanguage-$OSL_VERSION\2,x" \
          -xf $_src.tar.gz
      cd $_src
      #git checkout blender-fixes
      cd $CWD
    fi

    cd $_src

    # Always refresh the whole build!
    if [ -d build ]; then
      rm -rf build
    fi    
    mkdir build
    cd build

    cmake_d="-D CMAKE_BUILD_TYPE=Release"
    cmake_d="$cmake_d -D CMAKE_INSTALL_PREFIX=$_inst"
    cmake_d="$cmake_d -D BUILDSTATIC=ON"
    cmake_d="$cmake_d -D BUILD_TESTING=OFF"
    cmake_d="$cmake_d -D STOP_ON_WARNING=OFF"

    if [ $_with_built_openexr == true ]; then
      #cmake_d="$cmake_d -D OPENEXR_HOME=$INST/openexr" # XXX Not used!
      cmake_d="$cmake_d -D ILMBASE_HOME=$INST/openexr"
    fi

    if [ -d $INST/boost ]; then
      cmake_d="$cmake_d -D BOOST_ROOT=$INST/boost -D Boost_NO_SYSTEM_PATHS=ON"
      if $ALL_STATIC; then
        cmake_d="$cmake_d -D Boost_USE_STATIC_LIBS=ON"        
      fi
    fi

    if [ -d $INST/oiio ]; then
      cmake_d="$cmake_d -D OPENIMAGEIOHOME=$INST/oiio"
    fi

    if [ ! -z $LLVM_VERSION_FOUND ]; then
      cmake_d="$cmake_d -D LLVM_VERSION=$LLVM_VERSION_FOUND"
      if [ -d $INST/llvm ]; then
        cmake_d="$cmake_d -D LLVM_DIRECTORY=$INST/llvm"
        cmake_d="$cmake_d -D LLVM_STATIC=ON"
      fi
    fi

    cmake $cmake_d ../src

    make -j$THREADS && make install
    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "OpenShadingLanguage-$OSL_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set osl-$OSL_VERSION $osl_magic

    cd $CWD
    INFO "Done compiling OpenShadingLanguage-$OSL_VERSION!"
  else
    INFO "Own OpenShadingLanguage-$OSL_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-osl option."
  fi
}

#### Build OpenCOLLADA ####
_init_opencollada() {
  _src=$SRC/OpenCOLLADA-$OPENCOLLADA_VERSION
  _inst=$INST/opencollada-$OPENCOLLADA_VERSION
  _inst_shortcut=$INST/opencollada
}

clean_OpenCOLLADA() {
  _init_opencollada
  _clean
}

compile_OpenCOLLADA() {
  # To be changed each time we make edits that would modify the compiled results!
  opencollada_magic=6
  _init_opencollada

  # Clean install if needed!
  magic_compile_check opencollada-$OPENCOLLADA_VERSION $opencollada_magic
  if [ $? -eq 1 -o $OPENCOLLADA_FORCE_REBUILD == true ]; then
    clean_OpenCOLLADA
  fi

  if [ ! -d $_inst ]; then
    INFO "Building OpenCOLLADA-$OPENCOLLADA_VERSION"

    prepare_opt

    if [ ! -d $_src ]; then
      mkdir -p $SRC
      git clone $OPENCOLLADA_SOURCE $_src
    fi

    cd $_src

    # XXX For now, always update from latest repo...
    git pull origin master

    # Stick to same rev as windows' libs...
    git checkout e886e196673222f2f4bc32b936dc96419fff815f
    git reset --hard

    # Always refresh the whole build!
    if [ -d build ]; then
      rm -rf build
    fi
    mkdir build
    cd build

    cmake_d="-D CMAKE_BUILD_TYPE=Release"
    cmake_d="$cmake_d -D CMAKE_INSTALL_PREFIX=$_inst"
    cmake_d="$cmake_d -D USE_EXPAT=OFF"
    cmake_d="$cmake_d -D USE_LIBXML=ON"
    cmake_d="$cmake_d -D USE_STATIC=ON"

    cmake $cmake_d ../

    make -j$THREADS && make install
    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "OpenCOLLADA-$OPENCOLLADA_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set opencollada-$OPENCOLLADA_VERSION $opencollada_magic

    cd $CWD
    INFO "Done compiling OpenCOLLADA-$OPENCOLLADA_VERSION!"
  else
    INFO "Own OpenCOLLADA-$OPENCOLLADA_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-opencollada option."
  fi
}

#### Build FFMPEG ####
_init_ffmpeg() {
  _src=$SRC/ffmpeg-$FFMPEG_VERSION
  _inst=$INST/ffmpeg-$FFMPEG_VERSION
  _inst_shortcut=$INST/ffmpeg
}

clean_FFmpeg() {
  _init_ffmpeg
  _clean
}

compile_FFmpeg() {
  # To be changed each time we make edits that would modify the compiled result!
  ffmpeg_magic=3
  _init_ffmpeg

  # Clean install if needed!
  magic_compile_check ffmpeg-$FFMPEG_VERSION $ffmpeg_magic
  if [ $? -eq 1 -o $FFMPEG_FORCE_REBUILD == true ]; then
    clean_FFmpeg
  fi

  if [ ! -d $_inst ]; then
    INFO "Building ffmpeg-$FFMPEG_VERSION"

    prepare_opt

    if [ ! -d $_src ]; then
      INFO "Downloading ffmpeg-$FFMPEG_VERSION"
      mkdir -p $SRC
      wget -c $FFMPEG_SOURCE -O "$_src.tar.bz2"

      INFO "Unpacking ffmpeg-$FFMPEG_VERSION"
      tar -C $SRC -xf $_src.tar.bz2
    fi

    cd $_src

    extra=""

    if $VORBIS_USE; then
      extra="$extra --enable-libvorbis"
    fi

    if $THEORA_USE; then
      extra="$extra --enable-libtheora"
    fi

    if $XVID_USE; then
      extra="$extra --enable-libxvid"
    fi

    if $X264_USE; then
      extra="$extra --enable-libx264"
    fi

    if $VPX_USE; then
      extra="$extra --enable-libvpx"
    fi

    if $MP3LAME_USE; then
      extra="$extra --enable-libmp3lame"
    fi

    if $OPENJPEG_USE; then
      extra="$extra --enable-libopenjpeg"
    fi

    ./configure --cc="gcc -Wl,--as-needed" \
        --extra-ldflags="-pthread -static-libgcc" \
        --prefix=$_inst --enable-static \
        --disable-ffplay --disable-ffserver --disable-doc \
        --enable-gray \
        --enable-avfilter --disable-vdpau \
        --disable-bzlib --disable-libgsm --disable-libspeex \
        --enable-pthreads --enable-zlib --enable-stripping --enable-runtime-cpudetect \
        --disable-vaapi --disable-libfaac --disable-nonfree --enable-gpl \
        --disable-postproc --disable-x11grab --disable-librtmp --disable-libopencore-amrnb \
        --disable-libopencore-amrwb --disable-libdc1394 --disable-version3 --disable-outdev=sdl \
        --disable-outdev=alsa --disable-indev=sdl --disable-indev=alsa --disable-indev=jack \
        --disable-indev=lavfi $extra

    make -j$THREADS && make install
    make clean

    if [ -d $_inst ]; then
      _create_inst_shortcut
    else
      ERROR "FFmpeg-$FFMPEG_VERSION failed to compile, exiting"
      exit 1
    fi

    magic_compile_set ffmpeg-$FFMPEG_VERSION $ffmpeg_magic

    cd $CWD
    INFO "Done compiling ffmpeg-$FFMPEG_VERSION!"
  else
    INFO "Own ffmpeg-$FFMPEG_VERSION is up to date, nothing to do!"
    INFO "If you want to force rebuild of this lib, use the --force-ffmpeg option."
  fi
}


#### Install on DEB-like ####
get_package_version_DEB() {
    dpkg-query -W -f '${Version}' $1 | sed -r 's/.*:\s*([0-9]+:)(([0-9]+\.?)+).*/\2/'
}

check_package_DEB() {
  r=`apt-cache show $1 | grep -c 'Package:'`

  if [ $r -ge 1 ]; then
    return 0
  else
    return 1
  fi
}

check_package_version_match_DEB() {
  v=`apt-cache policy $1 | grep 'Candidate:' | sed -r 's/.*:\s*([0-9]+:)(([0-9]+\.?)+).*/\2/'`

  if [ -z "$v" ]; then
    return 1
  fi

  version_match $v $2
  return $?
}

check_package_version_ge_DEB() {
  v=`apt-cache policy $1 | grep 'Candidate:' | sed -r 's/.*:\s*([0-9]+:)?(([0-9]+\.?)+).*/\2/'`

  if [ -z "$v" ]; then
    return 1
  fi

  version_ge $v $2
  return $?
}

install_packages_DEB() {
  sudo apt-get install -y --force-yes $@
  if [ $? -ge 1 ]; then
    ERROR "apt-get failed to install requested packages, exiting."
    exit 1
  fi
}

install_DEB() {
  INFO ""
  INFO "Installing dependencies for DEB-based distribution"
  INFO ""
  INFO "`eval _echo "$COMMON_INFO"`"
  INFO ""

  read -p "Do you want to continue (Y/n)?"
  [ "$(echo ${REPLY:=Y} | tr [:upper:] [:lower:])" != "y" ] && exit

  if [ ! -z "`cat /etc/debian_version | grep ^6`"  ]; then
    if [ -z "`cat /etc/apt/sources.list | grep backports.debian.org`"  ]; then
      INFO "Looks like you're using Debian Squeeze which does have broken CMake"
      INFO "It is highly recommended to install cmake from backports, otherwise"
      INFO "compilation of some libraries could fail"
      INFO ""
      INFO "You could install newer CMake from debian-backports repository"
      INFO "Add this this line to your /etc/apt/sources.lixt:"
      INFO ""
      INFO "deb http://backports.debian.org/debian-backports squeeze-backports main"
      INFO ""
      INFO "and then run:"
      INFO ""
      INFO "sudo apt-get update && sudo apt-get install cmake=2.8.7-4~bpo60+1 sudo apt-get install cmake=2.8.7-4~bpo60+1"
      INFO ""
      INFO "(you could also add this reporisotry using GUI like synaptic)"
      INFO ""
      INFO "Hit Enter to continue running the script, or hit Ctrl-C to abort the script"

      read
      INFO ""
    fi
  fi

  sudo apt-get update

  # These libs should always be available in debian/ubuntu official repository...
  OPENJPEG_DEV="libopenjpeg-dev"
  VORBIS_DEV="libvorbis-dev"
  THEORA_DEV="libtheora-dev"

  _packages="gawk cmake cmake-curses-gui scons build-essential libjpeg-dev libpng-dev \
             libfreetype6-dev libx11-dev libxi-dev wget libsqlite3-dev libbz2-dev \
             libncurses5-dev libssl-dev liblzma-dev libreadline-dev $OPENJPEG_DEV \
             libopenal-dev libglew-dev yasm $THEORA_DEV $VORBIS_DEV \
             libsdl1.2-dev libfftw3-dev patch bzip2"

  OPENJPEG_USE=true
  VORBIS_USE=true
  THEORA_USE=true

  # Install newest libtiff-dev in debian/ubuntu.
  TIFF="libtiff"
  check_package_DEB $TIFF
  if [ $? -eq 0 ]; then
    _packages="$_packages $TIFF-dev"
  else
    TIFF="libtiff5"
    check_package_DEB $TIFF
    if [ $? -eq 0 ]; then
      _packages="$_packages $TIFF-dev"
    else
      TIFF="libtiff4"  # Some old distro, like e.g. ubuntu 10.04 :/
      check_package_DEB $TIFF
      if [ $? -eq 0 ]; then
        _packages="$_packages $TIFF-dev"
      fi
    fi
  fi

  GIT="git"
  check_package_DEB $GIT
  if [ $? -eq 0 ]; then
    INFO $GIT
    _packages="$_packages $GIT"
  else
    GIT="git-core"  # Some old distro, like e.g. ubuntu 10.04 :/
    check_package_DEB $GIT
    if [ $? -eq 0 ]; then
      INFO $GIT
      _packages="$_packages $GIT"
    fi
  fi

  if $WITH_ALL; then
    _packages="$_packages libspnav-dev libjack-dev"
  fi

  INFO ""
  install_packages_DEB $_packages

  INFO ""
  X264_DEV="libx264-dev"
  check_package_version_ge_DEB $X264_DEV $X264_VERSION_MIN
  if [ $? -eq 0 ]; then
    install_packages_DEB $X264_DEV
    X264_USE=true
  fi

  if $WITH_ALL; then
    INFO ""
    # Grmpf, debian is libxvidcore-dev and ubuntu libxvidcore4-dev!
    # Note: not since ubuntu 10.04
    XVID_DEV="libxvidcore-dev"
    check_package_DEB $XVID_DEV
    if [ $? -eq 0 ]; then
      install_packages_DEB $XVID_DEV
      XVID_USE=true
    else
      XVID_DEV="libxvidcore4-dev"
      check_package_DEB $XVID_DEV
      if [ $? -eq 0 ]; then
        install_packages_DEB $XVID_DEV
        XVID_USE=true
      fi
    fi

    INFO ""
    MP3LAME_DEV="libmp3lame-dev"
    check_package_DEB $MP3LAME_DEV
    if [ $? -eq 0 ]; then
      install_packages_DEB $MP3LAME_DEV
      MP3LAME_USE=true
    fi

    INFO ""
    VPX_DEV="libvpx-dev"
    check_package_version_ge_DEB $VPX_DEV $VPX_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_DEB $VPX_DEV
      VPX_USE=true
    fi
  fi

  INFO ""
  if $PYTHON_SKIP; then
    INFO "WARNING! Skipping Python installation, as requested..."
  else
    check_package_DEB python$PYTHON_VERSION_MIN-dev
    if [ $? -eq 0 ]; then
      install_packages_DEB python$PYTHON_VERSION_MIN-dev
      INFO ""
      if $NUMPY_SKIP; then
        INFO "WARNING! Skipping NumPy installation, as requested..."
      else
        check_package_DEB python$PYTHON_VERSION_MIN-numpy
        if [ $? -eq 0 ]; then
          install_packages_DEB python$PYTHON_VERSION_MIN-numpy
        else
          INFO "WARNING! Sorry, using python package but no numpy package available!"
        fi
      fi
      clean_Python
    else
      compile_Python
      INFO ""
      if $NUMPY_SKIP; then
        INFO "WARNING! Skipping NumPy installation, as requested..."
      else
        compile_Numpy
      fi
    fi
  fi

  INFO ""
  if $BOOST_SKIP; then
    INFO "WARNING! Skipping Boost installation, as requested..."
  else
    check_package_version_ge_DEB libboost-dev $BOOST_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_DEB libboost-dev

      boost_version=$(echo `get_package_version_DEB libboost-dev` | sed -r 's/^([0-9]+\.[0-9]+).*/\1/')

      check_package_DEB libboost-locale$boost_version-dev
      if [ $? -eq 0 ]; then
        install_packages_DEB libboost-locale$boost_version-dev libboost-filesystem$boost_version-dev \
                             libboost-regex$boost_version-dev libboost-system$boost_version-dev \
                             libboost-thread$boost_version-dev
        clean_Boost
      else
        compile_Boost
      fi
    else
      compile_Boost
    fi
  fi

  INFO ""
  if $OCIO_SKIP; then
    INFO "WARNING! Skipping OpenColorIO installation, as requested..."
  else
    check_package_version_ge_DEB libopencolorio-dev $OCIO_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_DEB libopencolorio-dev
      clean_OCIO
    else
      compile_OCIO
    fi
  fi

  INFO ""
  if $OPENEXR_SKIP; then
    INFO "WARNING! Skipping OpenEXR installation, as requested..."
  else
    check_package_version_ge_DEB libopenexr-dev $OPENEXR_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_DEB libopenexr-dev
      clean_OPENEXR
    else
      compile_OPENEXR
    fi
  fi

  INFO ""
  if $OIIO_SKIP; then
    INFO "WARNING! Skipping OpenImageIO installation, as requested..."
  else
    check_package_version_ge_DEB libopenimageio-dev $OIIO_VERSION_MIN
    if [ $? -eq 0 -a $_with_built_openexr == false ]; then
      install_packages_DEB libopenimageio-dev
      clean_OIIO
    else
      compile_OIIO
    fi
  fi

  if $WITH_OSL; then
    have_llvm=false

    if $LLVM_SKIP; then
      INFO "WARNING! Skipping LLVM installation, as requested (this also implies skipping OSL!)..."
    else
      INFO ""
      check_package_DEB llvm-$LLVM_VERSION-dev
      if [ $? -eq 0 ]; then
        install_packages_DEB llvm-$LLVM_VERSION-dev clang
        have_llvm=true
        LLVM_VERSION_FOUND=$LLVM_VERSION
        clean_LLVM
      else
        check_package_DEB llvm-$LLVM_VERSION_MIN-dev
        if [ $? -eq 0 ]; then
          install_packages_DEB llvm-$LLVM_VERSION_MIN-dev clang
          have_llvm=true
          LLVM_VERSION_FOUND=$LLVM_VERSION_MIN
          clean_LLVM
        else
          install_packages_DEB libffi-dev
          # LLVM can't find the debian ffi header dir
          _FFI_INCLUDE_DIR=`dpkg -L libffi-dev | grep -e ".*/ffi.h" | sed -r 's/(.*)\/ffi.h/\1/'`
          INFO ""
          compile_LLVM
          have_llvm=true
          LLVM_VERSION_FOUND=$LLVM_VERSION
        fi
      fi
    fi

    if $OSL_SKIP; then
      INFO "WARNING! Skipping OpenShadingLanguage installation, as requested..."
    else
      if $have_llvm; then
        INFO ""
        install_packages_DEB flex bison libtbb-dev
        # No package currently!
        INFO ""
        compile_OSL
      fi
    fi
  fi

  if $WITH_OPENCOLLADA; then
    if $OPENCOLLADA_SKIP; then
      INFO "WARNING! Skipping OpenCOLLADA installation, as requested..."
    else
      INFO ""
      install_packages_DEB libpcre3-dev libxml2-dev
      # Find path to libxml shared lib...
      _XML2_LIB=`dpkg -L libxml2-dev | grep -e ".*/libxml2.so"`
      # No package
      INFO ""
      compile_OpenCOLLADA
    fi
  fi

  INFO ""
  if $FFMPEG_SKIP; then
    INFO "WARNING! Skipping FFMpeg installation, as requested..."
  else
#    XXX Debian features libav packages as ffmpeg, those are not really compatible with blender code currently :/
#        So for now, always build our own ffmpeg.
#    check_package_DEB ffmpeg
#    if [ $? -eq 0 ]; then
#      install_packages_DEB ffmpeg
#      ffmpeg_version=`get_package_version_DEB ffmpeg`
#      INFO "ffmpeg version: $ffmpeg_version"
#      if [ ! -z "$ffmpeg_version" ]; then
#        if  dpkg --compare-versions $ffmpeg_version gt 0.7.2; then
#          install_packages_DEB libavfilter-dev libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev libswscale-dev
#          clean_FFmpeg
#        else
#          compile_FFmpeg
#        fi
#      fi
#    fi
    compile_FFmpeg
  fi
}


#### Install on RPM-like ####
rpm_flavour() {
  if [ -f /etc/redhat-release ]; then
    if [ "`grep '6\.' /etc/redhat-release`" ]; then
      RPM="RHEL"
    else
      RPM="FEDORA"
    fi
  elif [ -f /etc/SuSE-release ]; then
    RPM="SUSE"
  fi
}

get_package_version_RPM() {
  rpm_flavour
  if [ $RPM = "FEDORA" -o $RPM = "RHEL" ]; then
    yum info $1 | grep Version | tail -n 1 | sed -r 's/.*:\s+(([0-9]+\.?)+).*/\1/'
  elif [ $RPM = "SUSE" ]; then
    zypper info $1 | grep Version | tail -n 1 | sed -r 's/.*:\s+(([0-9]+\.?)+).*/\1/'
  fi  
}

check_package_RPM() {
  rpm_flavour
  if [ $RPM = "FEDORA" -o $RPM = "RHEL" ]; then
    r=`yum info $1 | grep -c 'Summary'`
  elif [ $RPM = "SUSE" ]; then
    r=`zypper info $1 | grep -c 'Summary'`
  fi

  if [ $r -ge 1 ]; then
    return 0
  else
    return 1
  fi
}

check_package_version_match_RPM() {
  v=`get_package_version_RPM $1`

  if [ -z "$v" ]; then
    return 1
  fi

  version_match $v $2
  return $?
}

check_package_version_ge_RPM() {
  v=`get_package_version_RPM $1`

  if [ -z "$v" ]; then
    return 1
  fi

  version_ge $v $2
  return $?
}

install_packages_RPM() {
  rpm_flavour
  if [ $RPM = "FEDORA" -o $RPM = "RHEL" ]; then
    sudo yum install -y $@
    if [ $? -ge 1 ]; then
      ERROR "yum failed to install requested packages, exiting."
      exit 1
    fi

  elif [ $RPM = "SUSE" ]; then
    sudo zypper --non-interactive install --auto-agree-with-licenses $@
    if [ $? -ge 1 ]; then
      ERROR "zypper failed to install requested packages, exiting."
      exit 1
    fi
  fi
}

install_RPM() {
  INFO ""
  INFO "Installing dependencies for RPM-based distribution"
  INFO ""
  INFO "`eval _echo "$COMMON_INFO"`"
  INFO ""

  read -p "Do you want to continue (Y/n)?"
  [ "$(echo ${REPLY:=Y} | tr [:upper:] [:lower:])" != "y" ] && exit

  # Enable non-free repositories for all flavours
  rpm_flavour
  if [ $RPM = "FEDORA" ]; then
    _fedora_rel="`egrep "[0-9]{1,}" /etc/fedora-release -o`"
    sudo yum -y localinstall --nogpgcheck \
    http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$_fedora_rel.noarch.rpm \
    http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$_fedora_rel.noarch.rpm

    sudo yum -y update

    # Install cmake now because of difference with RHEL
    sudo yum -y install cmake

  elif [ $RPM = "RHEL" ]; then
    sudo yum -y localinstall --nogpgcheck \
    http://download.fedoraproject.org/pub/epel/6/$(uname -i)/epel-release-6-8.noarch.rpm \
    http://download1.rpmfusion.org/free/el/updates/6/$(uname -i)/rpmfusion-free-release-6-1.noarch.rpm \
    http://download1.rpmfusion.org/nonfree/el/updates/6/$(uname -i)/rpmfusion-nonfree-release-6-1.noarch.rpm

    sudo yum -y update

    # Install cmake 2.8 from other repo
    mkdir -p $SRC
    if [ -f $SRC/cmake-2.8.8-4.el6.$(uname -m).rpm ]; then
      INFO ""
      INFO "Special cmake already installed"
    else
      curl -O ftp://ftp.pbone.net/mirror/atrpms.net/el6-$(uname -i)/atrpms/testing/cmake-2.8.8-4.el6.$(uname -m).rpm
      mv cmake-2.8.8-4.el6.$(uname -m).rpm $SRC/
      sudo rpm -ihv $SRC/cmake-2.8.8-4.el6.$(uname -m).rpm
    fi

  elif [ $RPM = "SUSE" ]; then
    # Install this now to avoid using the version from packman repository...
    if $WITH_ALL; then
      install_packages_RPM libjack-devel
    fi

    _suse_rel="`grep VERSION /etc/SuSE-release | gawk '{print $3}'`"

    INFO ""
    INFO "About to add 'packman' repository from http://packman.inode.at/suse/openSUSE_$_suse_rel/"
    INFO "This is only needed if you do not already have a packman repository enabled..."
    read -p "Do you want to add this repo (Y/n)?"
    if [ "$(echo ${REPLY:=Y} | tr [:upper:] [:lower:])" == "y" ]; then
      INFO "    Installing packman..."
      sudo zypper ar --refresh --name 'Packman Repository' http://ftp.gwdg.de/pub/linux/packman/suse/openSUSE_$_suse_rel/ ftp.gwdg.de-suse
      INFO "    Done."
    else
      INFO "    Skipping packman installation."
    fi
    sudo zypper --non-interactive --gpg-auto-import-keys update --auto-agree-with-licenses
  fi

  # These libs should always be available in fedora/suse official repository...
  OPENJPEG_DEV="openjpeg-devel"
  VORBIS_DEV="libvorbis-devel"
  THEORA_DEV="libtheora-devel"

  _packages="gcc gcc-c++ make scons libtiff-devel freetype-devel libjpeg-devel\
             libpng-devel libX11-devel libXi-devel wget ncurses-devel \
             readline-devel $OPENJPEG_DEV openal-soft-devel \
             glew-devel yasm $THEORA_DEV $VORBIS_DEV patch"

  OPENJPEG_USE=true
  VORBIS_USE=true
  THEORA_USE=true

  if [ $RPM = "FEDORA" -o $RPM = "RHEL" ]; then
    OPENEXR_DEV="openexr-devel"

    _packages="$_packages libsqlite3x-devel fftw-devel SDL-devel"

    if $WITH_ALL; then
      _packages="$_packages jack-audio-connection-kit-devel"
    fi

    INFO ""
    install_packages_RPM $_packages

    INFO ""
    X264_DEV="x264-devel"
    check_package_version_ge_RPM $X264_DEV $X264_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_RPM $X264_DEV
      X264_USE=true
    fi

    if $WITH_ALL; then
      INFO ""
      XVID_DEV="xvidcore-devel"
      check_package_RPM $XVID_DEV
      if [ $? -eq 0 ]; then
        install_packages_RPM $XVID_DEV
        XVID_USE=true
      fi

      INFO ""
      MP3LAME_DEV="lame-devel"
      check_package_RPM $MP3LAME_DEV
      if [ $? -eq 0 ]; then
        install_packages_RPM $MP3LAME_DEV
        MP3LAME_USE=true
      fi
    fi

  elif [ $RPM = "SUSE" ]; then
    OPENEXR_DEV="libopenexr-devel"

    _packages="$_packages cmake sqlite3-devel fftw3-devel libSDL-devel"

    INFO ""
    install_packages_RPM $_packages

    INFO ""
    X264_DEV="libx264-devel"
    check_package_version_ge_RPM $X264_DEV $X264_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_RPM $X264_DEV
      X264_USE=true
    fi

    if $WITH_ALL; then
      INFO ""
      XVID_DEV="libxvidcore-devel"
      check_package_RPM $XVID_DEV
      if [ $? -eq 0 ]; then
        install_packages_RPM $XVID_DEV
        XVID_USE=true
      fi

      INFO ""
      MP3LAME_DEV="libmp3lame-devel"
      check_package_RPM $MP3LAME_DEV
      if [ $? -eq 0 ]; then
        install_packages_RPM $MP3LAME_DEV
        MP3LAME_USE=true
      fi
    fi
  fi

  if $WITH_ALL; then
    INFO ""
    VPX_DEV="libvpx-devel"
    check_package_version_ge_RPM $VPX_DEV $VPX_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_RPM $VPX_DEV
      VPX_USE=true
    fi
    INFO ""
    install_packages_RPM libspnav-devel
  fi

  INFO ""
  if $PYTHON_SKIP; then
    INFO "WARNING! Skipping Python installation, as requested..."
  else
    check_package_version_match_RPM python3-devel $PYTHON_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_RPM python3-devel
      INFO ""
      if $NUMPY_SKIP; then
        INFO "WARNING! Skipping NumPy installation, as requested..."
      else
        check_package_version_match_RPM python3-numpy $NUMPY_VERSION_MIN
        if [ $? -eq 0 ]; then
          install_packages_RPM python3-numpy
        else
          INFO "WARNING! Sorry, using python package but no numpy package available!"
        fi
      fi
      clean_Python
    else
      compile_Python
      INFO ""
      if $NUMPY_SKIP; then
        INFO "WARNING! Skipping NumPy installation, as requested..."
      else
        compile_Numpy
      fi
    fi
  fi

  INFO ""
  if $BOOST_SKIP; then
    INFO "WARNING! Skipping Boost installation, as requested..."
  else
    check_package_version_ge_RPM boost-devel $BOOST_VERSION
    if [ $? -eq 0 ]; then
      install_packages_RPM boost-devel
      clean_Boost
    else
      compile_Boost
    fi
  fi

  INFO ""
  if $OCIO_SKIP; then
    INFO "WARNING! Skipping OpenColorIO installation, as requested..."
  else
    check_package_version_ge_RPM OpenColorIO-devel $OCIO_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_RPM OpenColorIO-devel
      clean_OCIO
    else
      compile_OCIO
    fi
  fi

  INFO ""
  if $OPENEXR_SKIP; then
    INFO "WARNING! Skipping OpenEXR installation, as requested..."
  else
    check_package_version_ge_RPM $OPENEXR_DEV $OPENEXR_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_RPM $OPENEXR_DEV
      clean_OPENEXR
    else
      compile_OPENEXR
    fi
  fi

  INFO ""
  if $OIIO_SKIP; then
    INFO "WARNING! Skipping OpenImageIO installation, as requested..."
  else
    check_package_version_ge_RPM OpenImageIO-devel $OIIO_VERSION_MIN
    if [ $? -eq 0 -a $_with_built_openexr == false ]; then
      install_packages_RPM OpenImageIO-devel
      clean_OIIO
    else
      compile_OIIO
    fi
  fi

  if $WITH_OSL; then
    have_llvm=false

    INFO ""
    if $LLVM_SKIP; then
      INFO "WARNING! Skipping LLVM installation, as requested (this also implies skipping OSL!)..."
    else
      # Problem compiling with LLVM 3.2 so match version 3.1 ...
      check_package_version_match_RPM llvm $LLVM_VERSION
      if [ $? -eq 0 ]; then
        if [ $RPM = "SUSE" ]; then
          install_packages_RPM llvm-devel llvm-clang-devel
        else
          install_packages_RPM llvm-devel clang-devel
        fi
        have_llvm=true
        LLVM_VERSION_FOUND=$LLVM_VERSION
        clean_LLVM
      else
        #
        # Better to compile it than use minimum version from repo...
        #
        install_packages_RPM libffi-devel
        # LLVM can't find the fedora ffi header dir...
        _FFI_INCLUDE_DIR=`rpm -ql libffi-devel | grep -e ".*/ffi.h" | sed -r 's/(.*)\/ffi.h/\1/'`
        INFO ""
        compile_LLVM
        have_llvm=true
        LLVM_VERSION_FOUND=$LLVM_VERSION
      fi
    fi

    if $OSL_SKIP; then
      INFO ""
      INFO "WARNING! Skipping OpenShadingLanguage installation, as requested..."
    else
      if $have_llvm; then
        # No package currently!
        INFO ""
        install_packages_RPM flex bison git
        if [ $RPM = "FEDORA" -o $RPM = "RHEL" ]; then
          install_packages_RPM tbb-devel
        fi
        INFO ""
        compile_OSL
      fi
    fi
  fi

  if $WITH_OPENCOLLADA; then
    if $OPENCOLLADA_SKIP; then
      INFO "WARNING! Skipping OpenCOLLADA installation, as requested..."
    else
      INFO ""
      install_packages_RPM pcre-devel libxml2-devel git
      # Find path to libxml shared lib...
      _XML2_LIB=`rpm -ql libxml2-devel | grep -e ".*/libxml2.so"`
      # No package...
      INFO ""
      compile_OpenCOLLADA
    fi
  fi

  if $FFMPEG_SKIP; then
    INFO "WARNING! Skipping FFMpeg installation, as requested..."
  else
    check_package_version_ge_RPM ffmpeg $FFMPEG_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_RPM ffmpeg ffmpeg-devel
      clean_FFmpeg
    else
      INFO ""
      compile_FFmpeg
    fi
  fi
}


#### Install on ARCH-like ####
get_package_version_ARCH() {
  pacman -Si $1 | grep Version | tail -n 1 | sed -r 's/.*:\s+(([0-9]+\.?)+).*/\1/'
}

check_package_ARCH() {
  r=`pacman -Si $1 | grep -c 'Description'`

  if [ $r -ge 1 ]; then
    return 0
  else
    return 1
  fi
}

check_package_version_match_ARCH() {
  v=`get_package_version_ARCH $1`

  if [ -z "$v" ]; then
    return 1
  fi

  version_match $v $2
  return $?
}

check_package_version_ge_ARCH() {
  v=`get_package_version_ARCH $1`

  if [ -z "$v" ]; then
    return 1
  fi

  version_ge $v $2
  return $?
}

install_packages_ARCH() {
  sudo pacman -S --needed --noconfirm $@
  if [ $? -ge 1 ]; then
    ERROR "pacman failed to install requested packages, exiting."
    exit 1
  fi
}

install_ARCH() {
  INFO ""
  INFO "Installing dependencies for ARCH-based distribution"
  INFO ""
  INFO "`eval _echo "$COMMON_INFO"`"
  INFO ""

  read -p "Do you want to continue (Y/n)?"
  [ "$(echo ${REPLY:=Y} | tr [:upper:] [:lower:])" != "y" ] && exit

  # Check for sudo...
  if [ ! -x "/usr/bin/sudo" ]; then
    INFO ""
    INFO "This script requires sudo but it is not installed."
    INFO "Please setup sudo according to:" 
    INFO "https://wiki.archlinux.org/index.php/Sudo"
    INFO "and try again."
    INFO ""
    exit
  fi

  sudo pacman -Sy

  # These libs should always be available in arch official repository...
  OPENJPEG_DEV="openjpeg"
  VORBIS_DEV="libvorbis"
  THEORA_DEV="libtheora"

  _packages="base-devel scons cmake libxi glew libpng libtiff wget openal \
             $OPENJPEG_DEV $VORBIS_DEV $THEORA_DEV yasm sdl fftw"

  OPENJPEG_USE=true
  VORBIS_USE=true
  THEORA_USE=true

  if $WITH_ALL; then
    # No libspacenav in official arch repos...
    _packages="$_packages jack"
  fi

  INFO ""
  install_packages_ARCH $_packages

  INFO ""
  X264_DEV="x264"
  check_package_version_ge_ARCH $X264_DEV $X264_VERSION_MIN
  if [ $? -eq 0 ]; then
    install_packages_ARCH $X264_DEV
    X264_USE=true
  fi

  if $WITH_ALL; then
    INFO ""
    XVID_DEV="xvidcore"
    check_package_ARCH $XVID_DEV
    if [ $? -eq 0 ]; then
      install_packages_ARCH $XVID_DEV
      XVID_USE=true
    fi

    INFO ""
    MP3LAME_DEV="lame"
    check_package_ARCH $MP3LAME_DEV
    if [ $? -eq 0 ]; then
      install_packages_ARCH $MP3LAME_DEV
      MP3LAME_USE=true
    fi

    INFO ""
    VPX_DEV="libvpx"
    check_package_version_ge_ARCH $VPX_DEV $VPX_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_ARCH $VPX_DEV
      VPX_USE=true
    fi
  fi

  INFO ""
  if $PYTHON_SKIP; then
    INFO "WARNING! Skipping Python installation, as requested..."
  else
    check_package_version_ge_ARCH python $PYTHON_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_ARCH python
      INFO ""
      if $WITH_NUMPY; then
        if $NUMPY_SKIP; then
          INFO "WARNING! Skipping NumPy installation, as requested..."
        else
          check_package_version_ge_ARCH python-numpy $NUMPY_VERSION_MIN
          if [ $? -eq 0 ]; then
            install_packages_ARCH python-numpy
          else
            INFO "WARNING! Sorry, using python package but no numpy package available!"
          fi
        fi
      fi
      clean_Python
    else
      compile_Python
      INFO ""
      if $WITH_NUMPY; then
        if $NUMPY_SKIP; then
          INFO "WARNING! Skipping NumPy installation, as requested..."
        else
          compile_Numpy
        fi
      fi
    fi
  fi

  INFO ""
  if $BOOST_SKIP; then
    INFO "WARNING! Skipping Boost installation, as requested..."
  else
    check_package_version_ge_ARCH boost $BOOST_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_ARCH boost
      clean_Boost
    else
      compile_Boost
    fi
  fi

  INFO ""
  if $OCIO_SKIP; then
    INFO "WARNING! Skipping OpenColorIO installation, as requested..."
  else
    check_package_version_ge_ARCH opencolorio $OCIO_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_ARCH opencolorio yaml-cpp tinyxml
      clean_OCIO
    else
      install_packages_ARCH yaml-cpp tinyxml
      compile_OCIO
    fi
  fi

  INFO ""
  if $OPENEXR_SKIP; then
    INFO "WARNING! Skipping OpenEXR installation, as requested..."
  else
    check_package_version_ge_ARCH openexr $OPENEXR_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_ARCH openexr
      clean_OPENEXR
    else
      compile_OPENEXR
    fi
  fi

  INFO ""
  if $OIIO_SKIP; then
    INFO "WARNING! Skipping OpenImageIO installation, as requested..."
  else
    check_package_version_ge_ARCH openimageio $OIIO_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_ARCH openimageio
      clean_OIIO
    else
      compile_OIIO
    fi
  fi

  if $WITH_OSL; then
    have_llvm=false

    INFO ""
    if $LLVM_SKIP; then
      INFO "WARNING! Skipping LLVM installation, as requested (this also implies skipping OSL!)..."
    else
      check_package_version_ge_ARCH llvm $LLVM_VERSION_MIN
      if [ $? -eq 0 ]; then
        install_packages_ARCH llvm clang
        have_llvm=true
        LLVM_VERSION=`check_package_version_ge_ARCH llvm`
        LLVM_VERSION_FOUND=$LLVM_VERSION
        clean_LLVM
      else
        install_packages_ARCH libffi
        # LLVM can't find the arch ffi header dir...
        _FFI_INCLUDE_DIR=`pacman -Ql libffi | grep -e ".*/ffi.h" | awk '{print $2}' | sed -r 's/(.*)\/ffi.h/\1/'`
        # LLVM 3.1 needs python2 to build and arch defaults to python3
        _PYTHON2_BIN="/usr/bin/python2"
        INFO ""
        compile_LLVM
        have_llvm=true
        LLVM_VERSION_FOUND=$LLVM_VERSION
      fi
    fi

    if $OSL_SKIP; then
      INFO ""
      INFO "WARNING! Skipping OpenShadingLanguage installation, as requested..."
    else
      if $have_llvm; then
        check_package_version_ge_ARCH openshadinglanguage $OSL_VERSION_MIN
        if [ $? -eq 0 ]; then
          install_packages_ARCH openshadinglanguage
          clean_OSL
        else
          #XXX Note: will fail to build with LLVM 3.2! 
          INFO ""
          install_packages_ARCH git intel-tbb
          INFO ""
          compile_OSL
        fi
      fi
    fi
  fi

  INFO ""
  if $WITH_OPENCOLLADA; then
    if $OPENCOLLADA_SKIP; then
      INFO "WARNING! Skipping OpenCOLLADA installation, as requested..."
    else
      INFO ""
      check_package_ARCH opencollada
      if [ $? -eq 0 ]; then
        install_packages_ARCH opencollada
        clean_OpenCOLLADA
      else
        install_packages_ARCH pcre git
        INFO ""
        compile_OpenCOLLADA
      fi
    # Find path to libxml shared lib...
    _XML2_LIB=`pacman -Ql libxml2 | grep -e ".*/libxml2.so$" | gawk '{print $2}'`
    fi
  fi

  INFO ""
  if $FFMPEG_SKIP; then
    INFO "WARNING! Skipping FFMpeg installation, as requested..."
  else
    check_package_version_ge_ARCH ffmpeg $FFMPEG_VERSION_MIN
    if [ $? -eq 0 ]; then
      install_packages_ARCH ffmpeg
      clean_FFmpeg
    else
      compile_FFmpeg
    fi
  fi
}


#### Printing User Info ####

print_info_ffmpeglink_DEB() {
  if $ALL_STATIC; then
    dpkg -L $_packages | grep -e ".*\/lib[^\/]\+\.a" | gawk '{ printf(nlines ? "'"$_ffmpeg_list_sep"'%s" : "%s", $0); nlines++ }'
  else
    dpkg -L $_packages | grep -e ".*\/lib[^\/]\+\.so" | gawk '{ printf(nlines ? "'"$_ffmpeg_list_sep"'%s" : "%s", gensub(/.*lib([^\/]+)\.so/, "\\1", "g", $0)); nlines++ }'
  fi
}

print_info_ffmpeglink_RPM() {
#  # XXX No static libs...
#  if $ALL_STATIC; then
#    rpm -ql $_packages | grep -e ".*\/lib[^\/]\+\.a" | gawk '{ printf(nlines ? "'"$_ffmpeg_list_sep"'%s" : "%s", $0); nlines++ }'
#  else
  rpm -ql $_packages | grep -e ".*\/lib[^\/]\+\.so" | gawk '{ printf(nlines ? "'"$_ffmpeg_list_sep"'%s" : "%s", gensub(/.*lib([^\/]+)\.so/, "\\1", "g", $0)); nlines++ }'
#  fi
}

print_info_ffmpeglink_ARCH() {
# No static libs...
  pacman -Ql $_packages | grep -e ".*\/lib[^\/]\+\.so$" | gawk '{ printf(nlines ? "'"$_ffmpeg_list_sep"'%s" : "%s", gensub(/.*lib([^\/]+)\.so/, "\\1", $0)); nlines++ }'
}

print_info_ffmpeglink() {
  # This func must only print a ';'-separated list of libs...
  if [ -z "$DISTRO" ]; then
    ERROR "Failed to detect distribution type"
    exit 1
  fi

  # Create list of packages from which to get libs names...
  _packages=""

  if $THEORA_USE; then
    _packages="$_packages $THEORA_DEV"
  fi

  if $VORBIS_USE; then
    _packages="$_packages $VORBIS_DEV"
  fi

  if $XVID_USE; then
    _packages="$_packages $XVID_DEV"
  fi

  if $VPX_USE; then
    _packages="$_packages $VPX_DEV"
  fi

  if $MP3LAME_USE; then
    _packages="$_packages $MP3LAME_DEV"
  fi

  if $X264_USE; then
    _packages="$_packages $X264_DEV"
  fi

  if $OPENJPEG_USE; then
    _packages="$_packages $OPENJPEG_DEV"
  fi

  if [ "$DISTRO" = "DEB" ]; then
    print_info_ffmpeglink_DEB
  elif [ "$DISTRO" = "RPM" ]; then
    print_info_ffmpeglink_RPM
  elif [ "$DISTRO" = "ARCH" ]; then
    print_info_ffmpeglink_ARCH
  # XXX TODO!
  else INFO "<Could not determine additional link libraries needed for ffmpeg, replace this by valid list of libs...>"
  fi
}

print_info() {
  INFO ""
  INFO ""
  INFO "****WARNING****"
  INFO "If you are experiencing issues building Blender, _*TRY A FRESH, CLEAN BUILD FIRST*_!"
  INFO "The same goes for install_deps itself, if you encounter issues, please first erase everything in $SRC and $INST"
  INFO "(provided obviously you did not add anything yourself in those dirs!), and run install_deps.sh again!"
  INFO "Often, changes in the libs built by this script, or in your distro package, cannot be handled simply, so..."
  INFO ""
  INFO ""
  INFO "If you're using CMake add this to your configuration flags:"

  _buildargs=""

  if $ALL_STATIC; then
    _1="-D WITH_STATIC_LIBS=ON"
    # XXX Force linking with shared SDL lib!
    _2="-D SDL_LIBRARY='libSDL.so;-lpthread'"
    INFO "  $_1"
    INFO "  $_2"
    _buildargs="$_buildargs $_1 $_2"
    # XXX Arch linux needs to link freetype dynamically...
    if [ "$DISTRO" = "ARCH" ]; then
      _1="-D FREETYPE_LIBRARY=/usr/lib/libfreetype.so"
      INFO "  $_1"
      _buildargs="$_buildargs $_1"
    fi
  fi

  if [ -d $INST/boost ]; then
    _1="-D BOOST_ROOT=$INST/boost"
    _2="-D Boost_NO_SYSTEM_PATHS=ON"
    INFO "  $_1"
    INFO "  $_2"
    _buildargs="$_buildargs $_1 $_2"
  elif $ALL_STATIC; then
    _1="-D WITH_BOOST_ICU=ON"
    INFO "  $_1"
    _buildargs="$_buildargs $_1"
    # XXX Arch linux fails static linking without these...
    if [ "$DISTRO" = "ARCH" ]; then
      _1="-D ICU_LIBRARY_DATA=/usr/lib/libicudata.so"
      _2="-D ICU_LIBRARY_I18N=/usr/lib/libicui18n.so"
      _3="-D ICU_LIBRARY_IO=/usr/lib/libicuio.so"
      _4="-D ICU_LIBRARY_LE=/usr/lib/libicule.so"
      _5="-D ICU_LIBRARY_LX=/usr/lib/libiculx.so"
      _6="-D ICU_LIBRARY_TU=/usr/lib/libicutu.so"
      _7="-D ICU_LIBRARY_UC=/usr/lib/libicuuc.so"
      INFO "  $_1"
      INFO "  $_2"
      INFO "  $_3"
      INFO "  $_4"
      INFO "  $_5"
      INFO "  $_6"
      INFO "  $_7"
      _buildargs="$_buildargs $_1 $_2 $_3 $_4 $_5 $_6 $_7"
    fi
  fi

  if [ -d $INST/openexr ]; then
    _1="-D OPENEXR_ROOT_DIR=$INST/openexr"
    INFO "  $_1"
    _buildargs="$_buildargs $_1"
  fi

  if $WITH_OSL; then
    _1="-D WITH_CYCLES_OSL=ON"
    _2="-D WITH_LLVM=ON"
    _3="-D LLVM_VERSION=$LLVM_VERSION_FOUND"
    INFO "  $_1"
    INFO "  $_2"
    INFO "  $_3"
    _buildargs="$_buildargs $_1 $_2 $_3"
    if [ -d $INST/osl ]; then
      _1="-D CYCLES_OSL=$INST/osl"
      INFO "  $_1"
      _buildargs="$_buildargs $_1"
    fi
    if [ -d $INST/llvm ]; then
      _1="-D LLVM_DIRECTORY=$INST/llvm"
      _2="-D LLVM_STATIC=ON"
      INFO "  $_1"
      INFO "  $_2"
      _buildargs="$_buildargs $_1 $_2"
    fi
  fi

  if $WITH_OPENCOLLADA; then
    _1="-D WITH_OPENCOLLADA=ON"
    INFO "  $_1"
    _buildargs="$_buildargs $_1"
    if $ALL_STATIC; then
      _1="-D XML2_LIBRARY=$_XML2_LIB"
      INFO "  $_1"
      _buildargs="$_buildargs $_1"
    fi
  fi

  _1="-D WITH_CODEC_FFMPEG=ON"
  _2="-D FFMPEG_LIBRARIES='avformat;avcodec;avutil;avdevice;swscale;rt;`print_info_ffmpeglink`'"
  INFO "  $_1"
  INFO "  $_2"
  _buildargs="$_buildargs $_1 $_2"
  if [ -d $INST/ffmpeg ]; then
    _1="-D FFMPEG=$INST/ffmpeg"
    INFO "  $_1"
    _buildargs="$_buildargs $_1"
  fi

  INFO ""
  INFO "Or even simpler, just run (in your blender-source dir):"
  INFO "  make -j$THREADS BUILD_CMAKE_ARGS=\"$_buildargs\""

  INFO ""
  INFO "If you're using SCons add this to your user-config:"

  if [ -d $INST/python-$PYTHON_VERSION_MIN ]; then
    INFO "BF_PYTHON = '$INST/python-$PYTHON_VERSION_MIN'"
    INFO "BF_PYTHON_ABI_FLAGS = 'm'"
  fi
  if $ALL_STATIC; then
    INFO "WITH_BF_STATICPYTHON = True"
  fi

  INFO "WITH_BF_OCIO = True"
  if [ -d $INST/ocio ]; then
    INFO "BF_OCIO = '$INST/ocio'"
  fi
  # XXX Always static for now :/
  INFO "WITH_BF_STATICOCIO = True"

  if [ -d $INST/openexr ]; then
    INFO "BF_OPENEXR = '$INST/openexr'"
  fi
  # XXX Always static for now :/
  INFO "WITH_BF_STATICOPENEXR = True"

  INFO "WITH_BF_OIIO = True"
  if [ -d $INST/oiio ]; then
    INFO "BF_OIIO = '$INST/oiio'"
  fi
  # XXX No more static oiio for now :/
  #if $ALL_STATIC; then
    #INFO "WITH_BF_STATICOIIO = True"
  #fi
  INFO "WITH_BF_CYCLES = True"

  if [ -d $INST/osl ]; then
    INFO "BF_OSL = '$INST/osl'"
  fi

  INFO "WITH_BF_BOOST = True"
  if [ -d $INST/boost ]; then
    INFO "BF_BOOST = '$INST/boost'"
  fi
  # XXX Broken in scons...
  #if $ALL_STATIC; then
    #INFO "WITH_BF_STATICBOOST = True"
  #fi

  if $WITH_OPENCOLLADA; then
    INFO "WITH_BF_COLLADA = True"
    if [ -d $INST/opencollada ]; then
      INFO "BF_OPENCOLLADA = '$INST/opencollada'"
    fi
  fi

  _ffmpeg_list_sep=" "
  if [ -d $INST/ffmpeg ]; then
    INFO "BF_FFMPEG = '$INST/ffmpeg'"
  fi
  if $ALL_STATIC; then
    INFO "WITH_BF_STATICFFMPEG = True"
    INFO "BF_FFMPEG_LIB_STATIC = '\${BF_FFMPEG_LIBPATH}/libavformat.a \${BF_FFMPEG_LIBPATH}/libavcodec.a \${BF_FFMPEG_LIBPATH}/libswscale.a \${BF_FFMPEG_LIBPATH}/libavutil.a \${BF_FFMPEG_LIBPATH}/libavdevice.a `print_info_ffmpeglink`'"
  else
    INFO "BF_FFMPEG_LIB = 'avformat avcodec swscale avutil avdevice `print_info_ffmpeglink`'"
  fi

  if ! $WITH_ALL; then
    INFO "WITH_BF_3DMOUSE = False"
  # No libspacenav in official arch repos...
  elif [ "$DISTRO" = "ARCH" ]; then
    INFO "WITH_BF_3DMOUSE = False"
  fi

  if $ALL_STATIC; then
    INFO "LLIB = ["xml2", "expat"] + LLIB"
  fi

  INFO ""
  INFO "NOTE: static build with scons are very tricky to set-up, if you choose that option"
  INFO "      you will likely have to edit these settings manually!"
  INFO ""
}

#### "Main" ####
# Detect distribution type used on this machine
if [ -f /etc/debian_version ]; then
  DISTRO="DEB"
  install_DEB
elif [ -f /etc/arch-release ]; then
  DISTRO="ARCH"
  install_ARCH
elif [ -f /etc/redhat-release -o /etc/SuSE-release ]; then
  DISTRO="RPM"
  install_RPM
else
  ERROR "Failed to detect distribution type"
  exit 1
fi

INFO ""
INFO "Running ldconfig..."
if [ $_need_boost_ldconfig == true ]; then
  sudo sh -c "echo \"$INST/boost/lib\" > /etc/ld.so.conf.d/boost.conf"
fi
if [ $_need_oiio_ldconfig == true ]; then
  sudo sh -c "echo \"$INST/oiio/lib\" > /etc/ld.so.conf.d/oiio.conf"
fi
if [ $_need_openexr_ldconfig == true ]; then
  sudo sh -c "echo \"$INST/openexr/lib\" > /etc/ld.so.conf.d/openexr.conf"
fi
sudo /sbin/ldconfig  # XXX OpenSuse does not include sbin in command path with sudo!!!
INFO ""

print_info | tee BUILD_NOTES.txt
INFO ""
INFO "This information has been written to BUILD_NOTES.txt"
INFO ""

# Switch back to user language.
LANG=LANG_BACK
export LANG
