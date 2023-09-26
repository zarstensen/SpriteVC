# syntax=docker/dockerfile:1

ARG ASEPRITE_VERSION="v1.3-rc6"
ARG PYTHON_VERSION=3.11.4

ARG ASEPRITE_SRC="usr/src/aseprite/"
ARG ASEPRITE_EXTDIR="/root/.config/aseprite/extensions/"

FROM python:${PYTHON_VERSION}-slim as base

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

################################################################################
# Create a stage for building/compiling the application.
FROM debian:12-slim as aseprite-build

# install requirements for building aseprite through apt-get

RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean \
    && apt-get update\
    && apt-get install -y git unzip \
    #Aseprite build dependencies
    g++ clang libc++-dev libc++abi-dev cmake ninja-build libx11-dev libxcursor-dev libxi-dev libgl1-mesa-dev libfontconfig1-dev

# build aseprite executable

ARG ASEPRITE_SRC
ARG ASEPRITE_VERSION

RUN git clone --jobs 24 --recursive --branch ${ASEPRITE_VERSION} https://github.com/aseprite/aseprite ${ASEPRITE_SRC}

ENV CC=clang
ENV CXX=clang++

RUN cmake \
    -G Ninja \
    -Wno-dev \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS:STRING=-stdlib=libc++ \
    -DCMAKE_EXE_LINKER_FLAGS:STRING=-stdlib=libc++ \
    -DLAF_BACKEND=none \
    -DENABLE_UI=ON \
    -S ${ASEPRITE_SRC} -B ${ASEPRITE_SRC}/build

RUN cmake --build ${ASEPRITE_SRC}/build --config Release -j 24
RUN chmod +xrw ${ASEPRITE_SRC}/build/bin/aseprite

# runtime dependencies of aseprite are copied over to /aseprite/dependencies, and should be copied directly to lib on the test image.

RUN mkdir -p /aseprite/dependencies
RUN ldd ${ASEPRITE_SRC}/build/bin/aseprite | awk '{if (match($3, /^\//)) print $3}' | xargs -I '{}' cp --parents '{}' /aseprite/dependencies
RUN ls -R /aseprite


################################################################################
# stage for configuring test extension at an location aseprite will look for locations at (ASEPRITE_EXTDIR).
#
FROM base as configure-test-extension

# publish extension to extension directory

ARG ASEPRITE_EXTDIR

# install python requirements for publishing script

COPY requirements.txt spritevc/
RUN pip install -r spritevc/requirements.txt

# install location

COPY publish.py  spritevc/
COPY src/ spritevc/src/
COPY modules/ spritevc/modules/

RUN cd spritevc \
    && python publish.py test none no_zip ${ASEPRITE_EXTDIR}

COPY test-docker/assets/ ${ASEPRITE_EXTDIR}/spritevc/assets/

# at this point aseprite has the extension that needs to be tested installed at the contents of ASERITE_EXTDIR_FILE,
# so this file should be copied over to the test image, in order to figure out which files to copy to transfer aseprite and the extension.


################################################################################
# final stage for running tests.
#
FROM base as test

ARG ASEPRITE_SRC
ARG ASEPRITE_EXTDIR

# Copy the executable and dependencies from the "build" stage.
COPY --from=aseprite-build ${ASEPRITE_SRC}/build/bin/ /bin/aseprite/
COPY --from=aseprite-build /aseprite/dependencies/lib/ /lib/

# Copy extension from the "configure" stage
COPY --from=configure-test-extension ${ASEPRITE_EXTDIR} ${ASEPRITE_EXTDIR} 

COPY test-docker/test_script.sh .

# What the container should run when it is started.
CMD [ "bash", "/test_script.sh" ]

# FROM scratch as test-report
# COPY --from=test /test_report.txt /
