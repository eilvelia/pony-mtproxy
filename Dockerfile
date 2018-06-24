FROM ponylang/ponyc:0.22.6
# FROM debian:9

# Installing ponyc
# RUN \
#   apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61" \
#   && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "DBE1D0A2" \
#   && echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" \
#     | tee -a /etc/apt/sources.list \
#   && apt-get -y install apt-transport-https \
#   && apt-get -y update \
#   && apt-get -yV install ponyc

COPY . /usr/app

WORKDIR /usr/app

# Building pony app
RUN cd /usr/app \
  && ./build

ENTRYPOINT ["/usr/app/pony-mtproxy"]
