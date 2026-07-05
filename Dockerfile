FROM debian:sid-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

RUN apt-get update && apt-get install -y curl xz-utils \
    devscripts \
    debhelper \
    dh-make \
    fakeroot \
    lintian \
    pbuilder \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/cache/apt/*

RUN curl -fsSL https://just.systems/install.sh | bash -s -- --to /usr/local/bin

RUN curl -fSL https://ziglang.org/download/0.16.0/zig-x86_64-linux-0.16.0.tar.xz -o zig.tar.xz \
    && mkdir /zig-x86_64-linux-0.16.0/ \
    && tar -xJf zig.tar.xz -C /zig-x86_64-linux-0.16.0/ \
    && ln -s /zig-x86_64-linux-0.16.0/zig /usr/local/bin/zig \
    && rm zig.tar.xz

WORKDIR /app

CMD ["/bin/bash"]
