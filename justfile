# list recipes
default:
    @just --list

build:
    zig build cross

pkg-deb:
    bash pkg/deb/create.sh

pkg-brew:
    bash pkg/brew/create.sh all

pkg-winget:
    bash pkg/winget/create.sh all

pkg: pkg-deb pkg-brew pkg-winget

img:
    docker build -t trigger -< Dockerfile

docker-build:
    docker run --rm -v $PWD:/app -w /app -u $(id -u):$(id -g) trigger just pkg

enter:
    docker run --rm -it -v $PWD:/app -w /app trigger /bin/bash

test-linux:
    docker run --rm -v $PWD:/app -w /app -u $(id -u):$(id -g) trigger ./examples/run_linux_event_tests.sh

clean:
    rm -rf zig-out zig-cache .zig-cache

clean-img:
    docker rmi trigger