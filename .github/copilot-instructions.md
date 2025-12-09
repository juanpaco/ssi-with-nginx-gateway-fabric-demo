# SSI Demo

This project's goal is to demonstrate nginx's SSI capabilities in a k8s environment.

There are three applications that get deployed to the cluster:

- `efferent-web`
- `layout-web`
- `social-feed-web`

Each project has its own folder found in the root of this project.

Within each project folder, you'll find two other folders:

- `application` - contains the application code (static html and css) as well as nginx configuration to expose the static assets
- `helm` - Helm configuration for the application

Off of the root there is also a `gateway` folder which contains the yaml for configuring an F5 nginx Gateway Fabric (NGF).

k3d is used to manage a local k8s cluster.

I have a local image repository inside of k3d for pushing images to. It runs at localhost:5001 from my host machine's perspective. It is called k3d-reg.localhost:5001 from inside the cluster.

When this all works, I should be able to hit localhost:8080 on my host machine, and the file at `efferent-web/application/index.html`, and the response should include content loaded from `layout-web` and `social-feed-web`, including the css file that lives in `layout-web`.

## Important!

If a line ends with "..." do not launch into an immediate response. Your programmers didn't make it possible to insert newlines in the interface, which is user-hostile. Wait until a line doesn't end in "...".

I understand that you have to respond with something. Absolute silence is not an option. When a new line ends in "...", just respond with "(waiting)". Literally only respond with that. In previous tests, you responded with also saying that you were waiting. "(waiting)" conveys everything I need to know when I end a line with "...".

