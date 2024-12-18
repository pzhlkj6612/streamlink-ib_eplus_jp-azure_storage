ARG BENTO4_BUILD_DIR=/tmp/cmakebuild

FROM python:3.13.1-slim-bookworm AS bento4-building

ARG BENTO4_BUILD_DIR

RUN apt update && \
    apt install \
    -y \
    --no-install-suggests \
    --no-install-recommends \
    'ca-certificates' 'libarchive-tools' 'curl' 'make' 'cmake' 'build-essential'

RUN curl -L 'https://github.com/axiomatic-systems/Bento4/archive/f8ce9a93de14972a9ddce442917ddabe21456f4d.zip' | \
        bsdtar -f- -x --strip-components=1 && \
    mkdir -p ${BENTO4_BUILD_DIR} && \
    cd ${BENTO4_BUILD_DIR} && \
    cmake -DCMAKE_BUILD_TYPE=Release "${OLDPWD}" && \
    make mp4decrypt -j2

# yt-dlp
RUN mkdir 'yt-dlp' && \
    curl -L "https://github.com/yt-dlp/yt-dlp/archive/refs/tags/2024.12.13.tar.gz" | \
        tar -C 'yt-dlp' -f- -x --gzip --strip-components=1 && \
    cd 'yt-dlp' && \
    python3 -m venv .venv-yt-dlp && . .venv-yt-dlp/bin/activate && \
    python3 devscripts/install_deps.py --include pyinstaller && \
    python3 devscripts/make_lazy_extractors.py && \
    python3 -m bundle.pyinstaller && \
    cp 'dist/yt-dlp_linux' "/opt/yt-dlp"

FROM python:3.13.1-slim-bookworm

RUN apt update && \
    apt install \
        -y \
        --no-install-suggests \
        --no-install-recommends \
        'ca-certificates' 'curl' 'git' 'python3-pip' 'xz-utils' && \
    python3 -m pip install pip -U

RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/s3tools/s3cmd/archive/9d17075b77e933cf9d7916435c426d38ab5bca5e.zip'

# RUN curl -L 'https://aka.ms/InstallAzureCLIDeb' | bash

# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/a/52989760
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/streamlink/streamlink/archive/a25de3b26d0f35103811e104c82e8b9eeadb4555.zip'

RUN mkdir -p '/opt/tools/bin' && \
    if [ "$(uname -m)" = 'x86_64' ]; then \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-x64_20240828.tar.gz'; \
    else \
        n_m3u8dl_re_url='https://github.com/nilaoda/N_m3u8DL-RE/releases/download/v0.2.1-beta/N_m3u8DL-RE_Beta_linux-arm64_20240828.tar.gz'; \
    fi && \
    curl -L "${n_m3u8dl_re_url}" | \
        tar -C '/opt/tools/bin' -f- -x --gzip --strip-components=1 && \
    chmod u+x '/opt/tools/bin/N_m3u8DL-RE'

ARG BENTO4_BUILD_DIR
COPY --from='bento4-building' ${BENTO4_BUILD_DIR}/mp4decrypt '/opt/tools/bin/mp4decrypt'

COPY --from='bento4-building' /opt/yt-dlp '/opt/tools/bin/yt-dlp'

# git - How to shallow clone a specific commit with depth 1? - Stack Overflow
#   https://stackoverflow.com/a/43136160
RUN mkdir '/SL-plugins' && \
    git -C '/SL-plugins' init && \
    git -C '/SL-plugins' remote add 'origin' 'https://github.com/pmrowla/streamlink-plugins.git' && \
    git -C '/SL-plugins' fetch --depth=1 'origin' 'fa794c0bd23a6439be9ec313ed71b4050339c752' && \
    git -C '/SL-plugins' switch --detach 'FETCH_HEAD'

RUN mkdir '/opt/ffmpeg' && \
    if [ "$(uname -m)" = 'x86_64' ]; then \
        ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-12-17-13-06/ffmpeg-n7.1-58-g10aaf84f85-linux64-gpl-7.1.tar.xz'; \
    else \
        ffmpeg_url='https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-12-17-13-06/ffmpeg-n7.1-58-g10aaf84f85-linuxarm64-gpl-7.1.tar.xz'; \
    fi && \
    curl -L "${ffmpeg_url}" | \
        tar -C '/opt/ffmpeg' -f- -x --xz --strip-components=1

ENV PATH="/opt/ffmpeg/bin:/opt/tools/bin:${PATH}"

VOLUME [ "/SL-downloads" ]

# for cookies.txt
RUN mkdir '/YTDLP'

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

ENTRYPOINT [ "/script.sh" ]
