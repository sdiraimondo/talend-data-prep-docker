FROM node:latest

ARG ARCHI

RUN echo "deb http://archive.debian.org/debian stretch main" > /etc/apt/sources.list
RUN echo "deb http://archive.debian.org/debian/ stretch contrib main non-free" > /etc/apt/sources.list

RUN apt update
#RUN apt install python2.7
#RUN ln -s /usr/bin/python2.7 /usr/bin/python
#RUN ln -s /usr/bin/python2.7 /usr/bin/python2

# Install PhantomJS for arm64
RUN if [ "$ARCHI" = "aarch64" ]; then \
		wget https://launchpad.net/ubuntu/+source/phantomjs/2.1.1+dfsg-1/+build/9053523/+files/phantomjs_2.1.1+dfsg-1_arm64.deb; \
		dpkg -i phantomjs_2.1.1+dfsg-1_arm64.deb; \
		wget https://github.com/fg2it/phantomjs-on-raspberry/releases/download/v2.1.1-jessie-stretch-arm64/phantomjs; \
		cp ./phantom /usr/bin/phantomjs; \
    fi

WORKDIR /var/local/
RUN git clone https://github.com/sdiraimondo/talend-data-prep
WORKDIR /var/local/talend-data-prep/dataprep-webapp/
RUN npm install

VOLUME /var/local/data-prep
EXPOSE 3000

CMD ["npm run serve"]
