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


ENV DEBIAN_FRONTEND="noninteractive" \
    TERM=dumb \
    DEBIAN_FRONTEND=noninteractive

# Variables must be references after they are created
ENV ANDROID_SDK_HOME="$ANDROID_HOME"
ENV ANDROID_NDK_HOME="$ANDROID_NDK"

ENV PATH="$JAVA_HOME/bin:$PATH:$ANDROID_SDK_HOME/tools/bin:$ANDROID_SDK_HOME/tools:$ANDROID_SDK_HOME/platform-tools:$ANDROID_NDK:$NVM_DIR"

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
    java -version

RUN echo "nvm nodejs, npm" && \
    mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash > /dev/null && \
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm' >> /etc/bash.bashrc && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    npm install -g npm && \
    npm cache clean --force > /dev/null && \
    rm -rf /tmp/* /var/tmp/*

RUN ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/node /usr/local/bin/node
RUN ln -s $NVM_DIR/versions/node/$NODE_VERSION/bin/npm /usr/local/bin/npm


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

RUN du -sh $ANDROID_HOME > /dev/null


# Copy sdk license agreement files.
RUN mkdir -p $ANDROID_HOME/licenses
COPY sdk/licenses/* $ANDROID_HOME/licenses/

WORKDIR /project
