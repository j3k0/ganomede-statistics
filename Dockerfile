FROM node:8-slim
EXPOSE 8000
MAINTAINER Jean-Christophe Hoelt <hoelt@fovea.cc>

RUN apt-get update && apt-get install -y \
   python2.7-minimal \
   build-essential \
 && rm -rf /var/lib/apt/lists/* && \
 ln -s /usr/bin/python2.7 /usr/bin/python

RUN useradd app -d /home/app
WORKDIR /home/app/code
COPY package.json package-lock.json /home/app/code/
RUN chown -R app /home/app

USER app
RUN npm install

COPY .eslintrc .eslintignore config.js coffeelint.json Makefile index.js statistics-worker.sh statistics-worker.coffee /home/app/code/
COPY tests /home/app/code/tests
COPY src /home/app/code/src

USER root
RUN chown -R app /home/app

WORKDIR /home/app/code
USER app
RUN ./node_modules/.bin/eslint src/ && \
	./node_modules/.bin/coffeelint -q src tests

CMD node_modules/.bin/forever index.js
