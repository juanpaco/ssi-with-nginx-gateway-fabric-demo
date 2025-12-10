# SSI with NGINX Gateway Fabric Demo

## Purpose

Ingress NGINX will be retired in March 2026.

NGINX Gateway Fabric (NGF) is a Gateway-API-compliant replacement.

I wanted to validate that NGINX's SSI capabilities would work with NGF.

## Prerequisites

- [k3d](https://k3d.io/stable/) for creating a local kubernetes cluster and image registry
  - `brew install k3d`
- A local image registry
  - `k3d registry create reg.localhost --port 5001`
- Creating a cluster with the local image registry
  - `k3d cluster create demo --registry-use k3d-reg.localhost:5001`
- kubectl
  - `brew install kubectl`

The demo can probably be achieved without using k3d, but you'd need to set up your cluster and container registry another way.

## Structure

There are four directories.

1. `gateway` - Contains yaml to apply to the cluster to set up a gateway
2. `efferent-web` - A web project with an HTML file that references content from two other web projects
  - `efferent-web/application/index.html` has two SSI directives
    1. A reference to `layout-web` that fetches a `<link>` that includes a stylesheet that `layout-web` also provides
    2. A reference to `social-feed-web` to get a hypothetical social feed that is inserted into an appropriate place in the `<body>`
3. `layout-web` - A web project that supplies styles and content to insert into an HTML page header for retrieving styles
4. `social-feed-web` - A web project that supplies a hypothetical social feed

Each of the `-web` projects has an `application` and `helm` directory.

In the `application` directory is found configuration for an nginx server and the static files that the respective server serves. In a future iteration of this demo, the projects will be Node.js-based.

The `helm` directory contains helm configuration for the application.

Each `-web` project also has a `build-and-deploy.sh` script that will build a container image, push it to the local image registry, and deploy the updated image to the cluster.

The root of the project has a `build-and-deploy-all.sh` script which invokes the `build-and-deploy.sh` script in each `-web` project as well as reapplying the `gateway` yaml files.

## Operation

- Start the system - `build-and-deploy-all.sh`
- Expose the gateway to your host: `kubectl port-forward svc/web-gw-nginx 8080:80`
- Open [http://localhost:8080](http://localhost:8080) in your browser

You should see something like:

![Screenshot showing an HTML page where the content is sourced through SSI](ssi-demo.png)

## Observations

It works, which is good.

Each application owns its own `httpRoute` configuration, which you'll find in its respective `helm/values.yml` file. Initially, the routing was configured in a centralized file, but one of my goals was to have the routing config live with the respective projects.

However, once the routes were moved to the respective projects, and unfortunate behavior emerged.

Note that the route definitions for `layout-web` and `social-feed-web` include code like the following (`layout-web`'s is used):

```yaml
httpRoute:
  enabled: true
  annotations: {}
  parentRefs:
  - name: web-gw
    sectionName: http
  hostnames: []
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /layout
    filters:
    - type: URLRewrite
      urlRewrite:
        path:
          type: ReplacePrefixMatch
          replacePrefixMatch: /layout
```

Notice that it has a `URLRewrite` that does nothing productive.

Without that `URLRewrite` rule, NGF generated nginx configuration such as the following for `layout-web`:

```yaml
location ^~ / {
    include /etc/nginx/includes/SnippetsFilter_http.server.location_default_ssi-on.conf;

    proxy_http_version 1.1;
    proxy_set_header Host "$gw_api_compliant_host";
    proxy_set_header X-Forwarded-For "$proxy_add_x_forwarded_for";
    proxy_set_header X-Real-IP "$remote_addr";
    proxy_set_header X-Forwarded-Proto "$scheme";
    proxy_set_header X-Forwarded-Host "$host";
    proxy_set_header X-Forwarded-Port "$server_port";
    proxy_set_header Upgrade "$http_upgrade";
    proxy_set_header Connection "$connection_upgrade";
    proxy_pass http://default_efferent-web_80$request_uri;
}

location ^~ /layout/ {
    proxy_http_version 1.1;
    proxy_set_header Host "$gw_api_compliant_host";
    proxy_set_header X-Forwarded-For "$proxy_add_x_forwarded_for";
    proxy_set_header X-Real-IP "$remote_addr";
    proxy_set_header X-Forwarded-Proto "$scheme";
    proxy_set_header X-Forwarded-Host "$host";
    proxy_set_header X-Forwarded-Port "$server_port";
    proxy_set_header Upgrade "$http_upgrade";
    proxy_set_header Connection "$connection_upgrade";
    proxy_pass http://default_layout-web_80$request_uri;
}
```

Notice `proxy_pass http://default_efferent-web_80$request_uri;`. For a reason I dont' understand, when that rule is invoked as part of an SSI directive's processing, the `$request_uri` is not the value provided in the SSI directive. It retains the original `/` from the browser's request.

For normal requests, that is exactly what would be desired. For the SSI directives, it would route the requests to `layout-web` correctly, but the path would always be what was entered into the brower's address bar. I verified this at one point by mounting `efferent-web` at `/efferent` rather than at `/`, and a request showed up in `layout-web`'s logs at `/efferent`. It doesn't just use `/`, it uses whatever was used in the address bar.

However, we then route is declared with that pointless `URLRewrite`, the nginx configuration generated is of the form (again, `layout-web`'s is used):

```yaml
location ^~ /layout/ {
  rewrite ^/layout([^?]*)? /layout$1?$args? break;

  proxy_http_version 1.1;
  proxy_set_header Host "$gw_api_compliant_host";
  proxy_set_header X-Forwarded-For "$proxy_add_x_forwarded_for";
  proxy_set_header X-Real-IP "$remote_addr";
  proxy_set_header X-Forwarded-Proto "$scheme";
  proxy_set_header X-Forwarded-Host "$host";
  proxy_set_header X-Forwarded-Port "$server_port";
  proxy_set_header Upgrade "$http_upgrade";
  proxy_set_header Connection "$connection_upgrade";
  proxy_pass http://default_layout-web_80;
}

location = /layout {
  rewrite ^/layout([^?]*)? /layout$1?$args? break;

  proxy_http_version 1.1;
  proxy_set_header Host "$gw_api_compliant_host";
  proxy_set_header X-Forwarded-For "$proxy_add_x_forwarded_for";
  proxy_set_header X-Real-IP "$remote_addr";
  proxy_set_header X-Forwarded-Proto "$scheme";
  proxy_set_header X-Forwarded-Host "$host";
  proxy_set_header X-Forwarded-Port "$server_port";
  proxy_set_header Upgrade "$http_upgrade";
  proxy_set_header Connection "$connection_upgrade";
  proxy_pass http://default_layout-web_80;
}
```

The requested URI is rewritten to what it was before and the request is passed along to the backing server. In this form, the SSI directive's path is preserved, and the content is properly loaded.

For my current research purposes, this works well enough, but I find it unsettling.

I don't think the configuration generated without the `URLRewrite` is wrong, per se, but it isn't useful for endpoints that are meant to supply content via SSI. I intend to do more research to see if I've just approach configuration incorrectly or if there is a gap in NGF's configurability for this kind of endpoint

## Questions

If you have any questions, feel free to contact me or file an issue on this repository.

## License

MIT

