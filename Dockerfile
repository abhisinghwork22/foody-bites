# Use a lightweight Nginx web server image
FROM nginx:alpine

# Copy our Foody Bites HTML file into Nginx's public web directory
COPY index.html /usr/share/nginx/html/index.html

# Expose port 80 so web traffic can reach the container
EXPOSE 80