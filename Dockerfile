FROM openjdk:8

MAINTAINER Angry Cactus Inc. <devops@angrycactus.io>

ENV GRAILS_VERSION 3.1.0

RUN  \
    echo "deb http://dl.bintray.com/rundeck/rundeck-deb /" | tee -a /etc/apt/sources.list.d/rundeck.list && \
    wget -qO- https://bintray.com/user/downloadSubjectPublicKey?username=bintray | apt-key add -

# Install system packages.
COPY system-requirements.txt /root/system-requirements.txt
RUN  \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get -y autoremove && \
    xargs apt-get -y -q install < /root/system-requirements.txt && \
    apt-get clean

# Install python packages.
COPY requirements.txt /root/requirements.txt
RUN pip install -r /root/requirements.txt

ENV HOME /var/lib/rundeck
ENV SHELL bash
ENV WORKON_HOME /var/lib/rundeck
WORKDIR /var/lib/rundeck

# Install grails necessary to send mails.
RUN wget https://github.com/grails/grails-core/releases/download/v$GRAILS_VERSION/grails-$GRAILS_VERSION.zip && \
    unzip grails-$GRAILS_VERSION.zip && \
    rm -rf grails-$GRAILS_VERSION.zip && \
    ln -s grails-$GRAILS_VERSION grails
ENV GRAILS_HOME /var/lib/rundeck/grails
ENV PATH $GRAILS_HOME/bin:$PATH

# Install robo.
RUN wget http://robo.li/robo.phar -O /usr/bin/robo && \
        chmod +x /usr/bin/robo

VOLUME /data

COPY conf /root/rundeck-config
COPY conf-templates /root/rundeck-config-templates
COPY jobs /root/jobs

COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["rundeck"]

EXPOSE 4440
