ARG osdistro=ubuntu
ARG oscodename=jammy

FROM $osdistro:$oscodename
LABEL maintainer="Walter Doekes <wjdoekes+aide@osso.nl>"
LABEL dockerfile-vcs=https://github.com/ossobv/aide-deb

ARG DEBIAN_FRONTEND=noninteractive

# This time no "keeping the build small". We only use this container for
# building/testing and not for running, so we can keep files like apt
# cache. We do this before copying anything and before getting lots of
# ARGs from the user. That keeps this bit cached.
RUN echo 'APT::Install-Recommends "0";' >/etc/apt/apt.conf.d/01norecommends && \
    . /etc/os-release && case $VERSION_ID in \
    8) printf '%s\n' >/etc/apt/sources.list \
        'deb http://apt.osso.nl/debian-old jessie main' \
        'deb http://apt.osso.nl/debian-security-old jessie/updates main';; \
    esac
# We'll be ignoring "debconf: delaying package configuration, since apt-utils
#   is not installed"
RUN . /etc/os-release && force= && case $VERSION_ID in 8) force='--force-yes';; esac && \
    apt-get update -q && \
    apt-get dist-upgrade -y && \
    apt-get install -y $force \
        ca-certificates curl \
        build-essential devscripts dh-autoreconf dpkg-dev equivs quilt && \
    printf "%s\n" \
        QUILT_PATCHES=debian/patches QUILT_NO_DIFF_INDEX=1 \
        QUILT_NO_DIFF_TIMESTAMPS=1 'QUILT_DIFF_OPTS="--show-c-function"' \
        'QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"' \
        >~/.quiltrc

# Apt-get prerequisites according to control file.
COPY control /build/debian/control
RUN . /etc/os-release && case $VERSION_ID in \
    8) sed -i -e '/libpcre2-dev/d;/libext2fs-dev/d' /build/debian/control;; \
    esac
RUN . /etc/os-release && force= && case $VERSION_ID in 8) force='--force-yes';; esac && \
    mk-build-deps --install --remove --tool "apt-get -y $force" /build/debian/control && \
    cp /build/debian/control /build/debian/control.new
RUN . /etc/os-release && case $VERSION_ID in \
    8) \
        cd /build && \
        curl https://github.com/PCRE2Project/pcre2/releases/download/pcre2-10.39/pcre2-10.39.tar.gz \
          -sSfLo pcre2-10.39.tar.gz.tar.gz && \
        test $(md5sum /build/pcre2-10.39.tar.gz.tar.gz | awk '{print $1}' | tee /dev/stderr) = 7389e3524de2cda3d21fde8c224febf1 && \
        tar zxf pcre2-10.39.tar.gz.tar.gz && \
        cd pcre2-10.39 && \
        CFLAGS='-fPIC -O2' ./configure --enable-shared=no --enable-static=yes && \
        make -j6 && \
        make install;; \
    esac

# debian, deb, jessie, aide, 0.18.6, '', 2osso0
ARG osdistro osdistshort oscodename upname upversion debepoch= debversion

COPY changelog /build/debian/changelog.new
RUN . /etc/os-release && \
    sed -i -e "1s/+[^+)]*)/+${osdistshort}${VERSION_ID})/;1s/) stable;/) ${oscodename};/" \
        /build/debian/changelog.new && \
    fullversion="${upversion}-${debversion}+${osdistshort}${VERSION_ID}" && \
    expected="${upname} (${debepoch}${fullversion}) ${oscodename}; urgency=medium" && \
    head -n1 /build/debian/changelog.new && \
    if test "$(head -n1 /build/debian/changelog.new)" != "${expected}"; \
    then echo "${expected}  <-- mismatch" >&2; false; fi

# Trick to allow caching of UPNAME*.tar.gz files. Download them
# once using the curl command below into .cache/* if you want. The COPY
# is made conditional by the "[z]" "wildcard". (We need one existing
# file (README.rst) so the COPY doesn't fail.)
COPY ./README.rst .cache/${upname}_${upversion}.orig.tar.g[z] /build/
# http://archive.ubuntu.com/ubuntu/pool/main/a/aide/aide_0.18.6.orig.tar.gz
RUN if ! test -s /build/${upname}_${upversion}.orig.tar.gz; then \
    url="http://archive.ubuntu.com/ubuntu/pool/main/a/${upname}/${upname}_${upversion}.orig.tar.gz" && \
    echo "Fetching: ${url}" >&2 && \
    curl -fLsS "${url}" -o /build/${upname}_${upversion}.orig.tar.gz; fi
# 3f464e9187dc812af140dd0f3f1c58f7 = 0.18.6
RUN test $(md5sum /build/${upname}_${upversion}.orig.tar.gz | awk '{print $1}') = 3f464e9187dc812af140dd0f3f1c58f7
RUN cd /build && tar zxf "${upname}_${upversion}.orig.tar.gz" && \
    mv debian "${upname}-${upversion}/"
COPY . /build/${upname}-${upversion}/debian/
# Remove data we accidentally copied when doing COPY . -- yes, the Dockerfile
# COPY statement is completely retarded -- and replace the changelog with our
# modified better one.
RUN rm -rf \
      /build/${upname}-${upversion}/debian/README.rst \
      /build/${upname}-${upversion}/debian/.cache && \
    mv -vf /build/${upname}-${upversion}/debian/changelog.new \
           /build/${upname}-${upversion}/debian/changelog && \
    mv -vf /build/${upname}-${upversion}/debian/control.new \
           /build/${upname}-${upversion}/debian/control && \
    . /etc/os-release && case $VERSION_ID in \
    8) echo 10 >/build/${upname}-${upversion}/debian/compat;; \
    esac
WORKDIR /build/${upname}-${upversion}

# Build!
RUN DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -us -uc -sa

# TODO: for bonus points, we could run quick tests here;
# for starters dpkg -i tests?

# Write output files (store build args in ENV first).
ENV oscodename=$oscodename osdistshort=$osdistshort \
    upname=$upname upversion=$upversion debversion=$debversion
RUN . /etc/os-release && fullversion=${upversion}-${debversion}+${osdistshort}${VERSION_ID} && \
    mkdir -p /dist/${upname}_${fullversion} && \
    mv /build/${upname}_${upversion}.orig.tar.gz /dist/${upname}_${fullversion}/ && \
    mv /build/*${fullversion}* /dist/${upname}_${fullversion}/ && \
    cd / && find dist/${upname}_${fullversion} -type f >&2
