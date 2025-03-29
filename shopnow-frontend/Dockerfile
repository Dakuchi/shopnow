FROM node:18

WORKDIR /app

COPY package*.json ./

RUN npx update-browserslist-db@latest

COPY . .

EXPOSE 3000

CMD ["npm", "start"]
