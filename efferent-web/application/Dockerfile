FROM nginx:stable-alpine

COPY nginx.conf /etc/nginx/nginx.conf

# Remove default config that conflicts with our custom nginx.conf                                                                              │
RUN rm -f /etc/nginx/conf.d/default.conf

COPY *.html *.css /usr/share/nginx/html/

EXPOSE 80

