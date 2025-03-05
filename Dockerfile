ARG ALPINE_VERSION=3.20
ARG TOOLS_DIR="/opt/tools"

FROM python:alpine${ALPINE_VERSION} AS prepare
ARG BENTO4_BUILD_DIR=/tmp/cmakebuild
ARG BENTO4_COMMIT=dc264854d1f76c370b65b18d9f303a95f7f21ab1
ARG TOOLS_DIR

RUN apk update \
    && apk add --no-cache \
    ca-certificates bash wget libgcc cmake make gcc g++ curl libarchive-tools

RUN curl -L "https://github.com/axiomatic-systems/Bento4/archive/$BENTO4_COMMIT.zip" | \
        bsdtar -f- -x --strip-components=1 && \
    mkdir -p ${BENTO4_BUILD_DIR} && \
    cd ${BENTO4_BUILD_DIR} && \
    cmake -DCMAKE_BUILD_TYPE=Release "${OLDPWD}" && \
    make mp4decrypt -j2

RUN mkdir -p ${TOOLS_DIR}/bin && \
    cp ${BENTO4_BUILD_DIR}/mp4decrypt ${TOOLS_DIR}/bin/mp4decrypt

RUN apk add binutils

# yt-dlp
RUN mkdir 'yt-dlp' && \
    curl -L "https://github.com/yt-dlp/yt-dlp/archive/refs/tags/2024.12.13.tar.gz" | \
        tar -C 'yt-dlp' -f- -x --gzip --strip-components=1 && \
    cd 'yt-dlp' && \
    python3 -m venv .venv-yt-dlp && . .venv-yt-dlp/bin/activate && \
    python3 devscripts/install_deps.py --include pyinstaller && \
    python3 devscripts/make_lazy_extractors.py && \
    python3 -m bundle.pyinstaller && \
    cp 'dist/yt-dlp_linux' "${TOOLS_DIR}/bin/yt-dlp"

# N_m3u8DL-RE
RUN mkdir "${TOOLS_DIR}/n_m3u8dl_re" && \
    if [ "$(uname -m)" = 'x86_64' ]; then \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.3.0-beta/N_m3u8DL-RE_v0.3.0-beta_linux-musl-x64_20241203.tar.gz'; \
    else \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.3.0-beta/N_m3u8DL-RE_v0.3.0-beta_linux-musl-arm64_20241203.tar.gz'; \
    fi && \
    curl -L "${n_m3u8dl_re_url}" | \
        tar -C "${TOOLS_DIR}/n_m3u8dl_re" -f- -x --gzip && \
    chmod u+x "${TOOLS_DIR}/n_m3u8dl_re/N_m3u8DL-RE"

FROM python:alpine${ALPINE_VERSION} AS runtime
ARG TOOLS_DIR

COPY --from=prepare ${TOOLS_DIR} ${TOOLS_DIR}

RUN apk add ffmpeg git bash

# s3cmd
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/s3tools/s3cmd/archive/9d17075b77e933cf9d7916435c426d38ab5bca5e.zip'

# RUN pip install \
#         --disable-pip-version-check \
#         --no-cache-dir \
#         --force-reinstall \
#         'https://github.com/Azure/azure-cli/archive/refs/tags/azure-cli-2.67.0.zip'

# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/a/52989760
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/streamlink/streamlink/archive/refs/tags/7.0.0.zip'
# git - How to shallow clone a specific commit with depth 1? - Stack Overflow
#   https://stackoverflow.com/a/43136160
RUN mkdir '/SL-plugins' && \
    git -C '/SL-plugins' init && \
    git -C '/SL-plugins' remote add 'origin' 'https://github.com/pmrowla/streamlink-plugins.git' && \
    git -C '/SL-plugins' fetch --depth=1 'origin' 'fa794c0bd23a6439be9ec313ed71b4050339c752' && \
    git -C '/SL-plugins' switch --detach 'FETCH_HEAD'

# RUN mkdir '/opt/ffmpeg' && \
#     if [ "$(uname -m)" = 'x86_64' ]; then \
#         ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-11-05-13-03/ffmpeg-n7.1-16-g15035aaec0-linux64-gpl-7.1.tar.xz'; \
#     else \
#         ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-11-05-13-03/ffmpeg-n7.1-16-g15035aaec0-linuxarm64-gpl-7.1.tar.xz'; \
#     fi && \
#     curl -L "${ffmpeg_url}" | \
#         tar -C '/opt/ffmpeg' -f- -x --xz --strip-components=1

ENV PATH="${TOOLS_DIR}/n_m3u8dl_re:${TOOLS_DIR}/bin:${PATH}"

VOLUME [ "/SL-downloads" ]

# for cookies.txt
RUN mkdir '/YTDLP'

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

ENTRYPOINT [ "/script.sh" ]
