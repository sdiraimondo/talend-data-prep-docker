FROM node:latest

WORKDIR /var/local/
RUN git https://github.com/Talend/data-prep/
WORKDIR /var/local/data-prep/dataprep-webapp/
RUN npm install

VOLUME /var/local/data-prep
EXPOSE 3000

CMD ["npm run serve"]
