FROM nginx:alpine

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy ONLY the frontend application file (prevents leaking main.tf)
COPY index.html /usr/share/nginx/html/index.html

# Copy custom Nginx config that listens on port 8080
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 8080 to match Cloud Run requirements
EXPOSE 8080