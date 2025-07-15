# Stage 1: Build the frontend
FROM node:14.16.0 AS builder

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
# You may want to COPY a config.json here if needed

RUN npm run build

# Stage 2: Serve with nginx
FROM nginx:alpine

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy built frontend from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Optionally copy a custom nginx config
# COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
