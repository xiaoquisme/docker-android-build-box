FROM ubuntu:18.04

RUN uname -a && uname -m

ENV ANDROID_HOME="/opt/android-sdk" \
    ANDROID_NDK="/opt/android-sdk/ndk/current"

# support amd64 and arm64
RUN JDK_PLATFORM=$(if [ "$(uname -m)" = "aarch64" ]; then echo "arm64"; else echo "amd64"; fi) && \
    echo export JDK_PLATFORM=$JDK_PLATFORM >> /etc/jdk.env && \
    echo export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-$JDK_PLATFORM/" >> /etc/jdk.env && \
    echo . /etc/jdk.env >> /etc/bash.bashrc && \
    echo . /etc/jdk.env >> /etc/profile

ENV TZ=America/Los_Angeles

# Get the latest version from https://developer.android.com/studio/index.html
ENV ANDROID_SDK_TOOLS_VERSION="4333796"
ENV NDK_VERSION="16.1.4479499"

# nodejs version
ENV NODE_VERSION="8.17.0"
ENV NVM_DIR=/usr/local/nvm

# Set locale
ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US.UTF-8" \
    LC_ALL="en_US.UTF-8"

RUN apt-get clean && \
    apt-get update -qq && \
    apt-get install -qq -y apt-utils locales && \
    locale-gen $LANG

ENV DEBIAN_FRONTEND="noninteractive" \
    TERM=dumb \
    DEBIAN_FRONTEND=noninteractive

# Variables must be references after they are created
ENV ANDROID_SDK_HOME="$ANDROID_HOME"
ENV ANDROID_NDK_HOME="$ANDROID_NDK"

ENV PATH="$JAVA_HOME/bin:$PATH:$ANDROID_SDK_HOME/tools/bin:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$ANDROID_NDK"

WORKDIR /tmp

# Installing packages
RUN apt-get update -qq > /dev/null && \
    apt-get install -qq locales > /dev/null && \
    locale-gen "$LANG" > /dev/null && \
    apt-get install -qq --no-install-recommends \
        autoconf \
        build-essential \
        cmake \
        curl \
        file \
        git \
        ocaml \
        openjdk-8-jdk \
        openssh-client \
        unzip \
        vim-tiny \
        wget \
        zip \
        zipalign > /dev/null

RUN echo "JVM directories: `ls -l /usr/lib/jvm/`" && \
    . /etc/jdk.env && \
    echo "Java version (default):" && \
    java -version && \
    echo "set timezone" && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN echo "nvm nodejs, npm" && \
    mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash > /dev/null && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    nvm install $NODE_VERSION && \
    nvm alias default 8.17.0 && \
    nvm use default > /dev/null

# Install Android SDK
RUN echo "sdk tools ${ANDROID_SDK_TOOLS_VERSION}" && \
    wget --quiet --output-document=sdk-tools.zip \
        "https://dl.google.com/android/repository/sdk-tools-linux-${ANDROID_SDK_TOOLS_VERSION}.zip" && \
    mkdir --parents "$ANDROID_HOME" && \
    unzip -q sdk-tools.zip -d "$ANDROID_HOME" && \
    rm --force sdk-tools.zip

# Install SDKs
# Please keep these in descending order!
# The `yes` is for accepting all non-standard tool licenses.
RUN mkdir --parents "$ANDROID_HOME/.android/" && \
    echo '### User Sources for Android SDK Manager' > \
        "$ANDROID_HOME/.android/repositories.cfg" && \
    . /etc/jdk.env && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager --licenses > /dev/null

# List all available packages.
# redirect to a temp file `packages.txt` for later use and avoid show progress
RUN . /etc/jdk.env && \
    "$ANDROID_HOME"/tools/bin/sdkmanager --list > packages.txt && \
    cat packages.txt | grep -v '='

#
# https://developer.android.com/studio/command-line/sdkmanager.html
#
RUN echo "platforms" && \
    . /etc/jdk.env && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager \
        "platforms;android-26" \
        "platforms;android-25" \
        "platforms;android-24" \
        "platforms;android-23" \
        "platforms;android-22" \
        "platforms;android-21" \
        "platforms;android-20" \
        "platforms;android-19" > /dev/null

RUN echo "platform tools" && \
    . /etc/jdk.env && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager \
        "platform-tools" > /dev/null

RUN echo "build tools 19-26" && \
    . /etc/jdk.env && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager \
        "build-tools;26.0.2" "build-tools;26.0.1" "build-tools;26.0.0" \
        "build-tools;25.0.3" "build-tools;25.0.2" \
        "build-tools;25.0.1" "build-tools;25.0.0" \
        "build-tools;24.0.3" "build-tools;24.0.2" \
        "build-tools;24.0.1" "build-tools;24.0.0"\
        "build-tools;23.0.3" "build-tools;23.0.2" "build-tools;23.0.1" \
        "build-tools;22.0.1" \
        "build-tools;21.1.2" \
        "build-tools;20.0.0" \
        "build-tools;19.1.0"



RUN echo "bundletool" && \
    wget -q https://github.com/google/bundletool/releases/download/1.9.1/bundletool-all-1.9.1.jar -O bundletool.jar && \
    mv bundletool.jar $ANDROID_SDK_HOME/tools/

RUN echo "NDK" && \
    NDK=$(grep 'ndk;' packages.txt | grep $NDK_VERSION | tail -n1 | awk '{print $1}') && \
    NDK_VERSION=$(echo $NDK | awk -F\; '{print $2}') && \
    echo "Installing $NDK" && \
    . /etc/jdk.env && \
    yes | "$ANDROID_HOME"/tools/bin/sdkmanager "$NDK" > /dev/null && \
    ln -sv $ANDROID_HOME/ndk/${NDK_VERSION} ${ANDROID_NDK}

# List sdk and ndk directory content
RUN ls -l $ANDROID_HOME && \
    ls -l $ANDROID_HOME/ndk && \
    ls -l $ANDROID_HOME/ndk/*

RUN du -sh $ANDROID_HOME


# Copy sdk license agreement files.
RUN mkdir -p $ANDROID_HOME/licenses
COPY sdk/licenses/* $ANDROID_HOME/licenses/
# install az
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash
# install watchman
ENV WATCH_MAN_VERSION="v2022.05.30.00"

RUN wget -q https://github.com/facebook/watchman/releases/download/$WATCH_MAN_VERSION/watchman-$WATCH_MAN_VERSION-linux.zip -O watchman.zip && \
    unzip watchman.zip && \
    cd watchman-$WATCH_MAN_VERSION-linux && \
    mkdir -p /usr/local/{bin,lib} /usr/local/var/run/watchman && \
    cp bin/* /usr/local/bin && \
    cp lib/* /usr/local/lib && \
    chmod 755 /usr/local/bin/watchman && \
    chmod 2777 /usr/local/var/run/watchman &&\
    watchman -v


WORKDIR /project
