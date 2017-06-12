FROM ppc64le/ubuntu:16.04

RUN apt-get update
RUN apt-get -y install libtool curl git golang jq autoconf libboost-system-dev libboost-filesystem-dev && apt-get clean
RUN apt-get -y install npm libdb++-dev libboost-chrono-dev libboost-program-options-dev  && apt-get clean
RUN apt-get -y install bsdmainutils libboost-test-dev libboost-thread-dev libevent-dev  && apt-get clean
RUN apt-get -y install libqt5gui5 libqt5core5a libqt5dbus5 qttools5-dev qttools5-dev-tools libprotobuf-dev protobuf-compiler  && apt-get clean
RUN npm install -g node-gyp-install

COPY NAE/help.html /etc/NAE/help.html
COPY NAE/screenshot.jpg /etc/NAE

COPY NAE/AppDef.json /etc/NAE/AppDef.json
RUN curl --fail -X POST -d @/etc/NAE/AppDef.json https://api.jarvice.com/jarvice/validate

RUN cd /root
RUN git clone https://github.com/ElementsProject/elements.git
RUN elements/autogen.sh
RUN elements/configure --enable-cxx --disable-shared --with-pic --prefix=/root/frb/elements --with-incompatible-bdb
RUN cd elements
RUN make && make install

RUN cd ~ && mkdir /root/blockchain-demo
COPY build.sh /root/blockchain-demo 
COPY start_demo.sh /root/blockchain-demo 
COPY stop_demo.sh /root/blockchain-demo 
RUN mkdir /root/blockchain-demo/src
ADD  src /root/blockchain-demo/src
RUN mkdir /root/blockchain-demo/demo
ADD  demo /root/blockchain-demo/demo
RUN mv /root/frb/elements/bin/elem* /usr/local/bin

