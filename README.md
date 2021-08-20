# config-reloader-sidecar

A small (3MB uncompressed docker image), efficient (via inotify) sidecar to trigger application reloads when configuration changes.

## Rationale

A fairly common way to implement configuration hot-reloading is to have the app re-read configuration files when receiving a specific [unix signal](https://en.wikipedia.org/wiki/Signal_(IPC)), usually [SIGHUP](https://en.wikipedia.org/wiki/SIGHUP).

Applications using this method include:
- [nginx](https://nginx.org/en/docs/control.html)
- [apache](https://httpd.apache.org/docs/2.4/stopping.html#hup)
- [sshd](https://apple.stackexchange.com/questions/88598/how-to-have-sshd-re-read-its-config-file-without-killing-ssh-connections)
- [gunicorn](https://docs.gunicorn.org/en/stable/signals.html)
- [uwsgi](https://uwsgi-docs.readthedocs.io/en/latest/Management.html)
- [mysqld](https://dev.mysql.com/doc/refman/8.0/en/unix-signal-response.html)
- [logstash](https://www.elastic.co/guide/en/logstash/current/reloading-config.html)
- [postgresql](https://www.postgresql.org/docs/current/app-pg-ctl.html)
- [pgbouncer](https://www.pgbouncer.org/usage.html#signals)

In Kubernetes, the "recommended" / usual way of managing configuration is instead to:
- Have a ConfigMap (or Secret) holding the configuration
- When it changes, trigger a rolling-upgrade of the matching Deployment or DaemonSet

While this method is great to ensure configuration changes are highly visible and ensures all replicas use the same config (see immutable infrastructure), it is best for stateless apps which can easily handle rolling upgrades.

Stateful apps, by contrast, might be better off reloading their config so as to not disrupt long-lived open connections, or not to incur a long restart time.

In Kubernetes, an upgrade to a ConfigMap or Secret is _eventually_ (note: see gotchas) propagated to the running Pods, meaning we can watch configuration loaded via ConfigMaps or Secrets and send a signal to the main app when it changes, triggering a hot reload.

The `config-reloader-sidecar` exists specifically for that use case!

## How it works

`config-reloader-sidecar` uses Go's [fsnotify](https://pkg.go.dev/gopkg.in/fsnotify.v1) package to watch one (or more) configuration folders, and send a signal to a process when any change is detected within that folder. This includes file created, file updated, file renamed & file deleted, but excludes file permissions changes.

`config-reloader-sidecar` needs to run, as the name implies, as a separate container in the same Pod as the application you want to reload, i.e. a [sidecar](https://kubernetes.io/docs/concepts/workloads/pods/#using-pods).

In addition, you'll need to set [`shareProcessNamespace: true` on your Pod](https://kubernetes.io/docs/tasks/configure-pod-container/share-process-namespace/) to send signals across containers.

`config-reloader-sidecar` is then configured through the following env vars:
- `CONFIG_DIR`: comma-separated list of configuration directories to watch (mandatory)
- `PROCESS_NAME`: process to send the signal to (mandatory)
- `RELOAD_SIGNAL`: signal to send (optional, defaults to `SIGHUP`)

## Example Pod configuration

```yaml
TODO
```

## Gotchas

### Share Process Namespace

In order for the sidecar to find which process to send the signal to, the Pod needs to be configured to [Share Process Namespace](https://kubernetes.io/docs/tasks/configure-pod-container/share-process-namespace/) with `shareProcessNamespace: true`.

### Update speed

You might noticed when editing a Secret or ConfigMap that your process isn't being reloaded immediately.

This is because the projected values of ConfigMaps and Secrets are not updated exactly when the underlying object changes, but instead they're [updated periodically](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/#mounted-configmaps-are-updated-automatically) according to the `syncFrequency` argument to the [kubelet config](https://kubernetes.io/docs/reference/config-api/kubelet-config.v1beta1/). This defaults to 1 minute.

### Config files mounted via `subPath` are never updated

This is a long-standing Kubernetes issue: ConfigMap and Secrets mounted as files with a `subPath` key do not get updated by the kubelet. See [issue #50345](https://github.com/kubernetes/kubernetes/issues/50345) on Github.

The (pretty ugly) workaround involves [mounting the secret/configmap without subPath in a different folder and manually creating a symlink from an initContainer ahead of time to that folder](https://github.com/kubernetes/kubernetes/issues/50345#issuecomment-400647420), or if possible at all switching to not using `subPath`.
