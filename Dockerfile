FROM ubuntu:jammy

RUN apt update && \
    apt install \
        -y \
        --no-install-suggests \
        --no-install-recommends \
        'curl' 'git' 'python3-pip' 'xz-utils' && \
    python3 -m pip install pip -U

RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/s3tools/s3cmd/archive/9d17075b77e933cf9d7916435c426d38ab5bca5e.zip'

RUN curl -L 'https://aka.ms/InstallAzureCLIDeb' | bash

# python - Can I force pip to make a shallow checkout when installing from git? - Stack Overflow
#   https://stackoverflow.com/a/52989760
RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/streamlink/streamlink/archive/8d73b096066e3a84af4057f5aa589f7a65e5ab34.zip'

RUN pip install \
        --disable-pip-version-check \
        --no-cache-dir \
        --force-reinstall \
        'https://github.com/pzhlkj6612/yt-dlp-fork/archive/50c29352312f5662acf9a64b0012766f5c40af61.zip'

# git - How to shallow clone a specific commit with depth 1? - Stack Overflow
#   https://stackoverflow.com/a/43136160
RUN mkdir '/SL-plugins' && \
    git -C '/SL-plugins' init && \
    git -C '/SL-plugins' remote add 'origin' 'https://github.com/code-with-IPID/streamlink-plugins.git' && \
    git -C '/SL-plugins' fetch --depth=1 'origin' '8cf88410ed8357082c966ef0361ac1dff8598f09' && \
    git -C '/SL-plugins' switch --detach 'FETCH_HEAD'

RUN mkdir '/opt/ffmpeg' && \
    curl -L 'https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2024-03-30-12-47/ffmpeg-n6.1.1-27-gf4a6db1222-linux64-gpl-6.1.tar.xz' | \
        tar -C '/opt/ffmpeg' -f- -x --xz --strip-components=1

ENV PATH="/opt/ffmpeg/bin:${PATH}"

VOLUME [ "/SL-downloads" ]

# for cookies.txt
RUN mkdir '/YTDLP'

COPY --chown=0:0 --chmod=700 ./script.sh /script.sh

ENTRYPOINT [ "/script.sh" ]
