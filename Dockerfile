FROM node:latest

WORKDIR /var/local/
RUN git clone https://github.com/sdiraimondo/talend-data-prep
WORKDIR /var/local/talend-data-prep/dataprep-webapp/
RUN npm install

VOLUME /var/local/data-prep
EXPOSE 3000

CMD ["npm run serve"]
