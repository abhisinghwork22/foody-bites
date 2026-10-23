FROM node:20-alpine

WORKDIR /app

# Copy only package.json first for Docker layer caching
COPY package.json ./
RUN npm install --omit=dev

# Copy application files (still prevents leaking main.tf!)
COPY server.js ./
COPY index.html ./

EXPOSE 8080

CMD ["npm", "start"]