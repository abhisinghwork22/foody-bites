FROM nginx:alpine

# Copy your website files into Nginx's public folder
COPY . /usr/share/nginx/html

# Copy our custom Nginx config that listens on port 8080
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 8080 to match Cloud Run requirements
EXPOSE 8080