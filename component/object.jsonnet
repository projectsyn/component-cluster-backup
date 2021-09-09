local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

local schedule = import 'schedule.libsonnet';

local namespace = kube.Namespace(params.namespace);

local namespaceMeta = {
  metadata+: { namespace: params.namespace },
};

local sa = kube.ServiceAccount('object-backup') + namespaceMeta;

local role = kube.ClusterRole('cluster-backup-object-reader') {
  rules: [
    {
      apiGroups: [ '*' ],
      resources: [ '*' ],
      verbs: [ 'get', 'list' ],
    },
  ],
};

local binding = kube.ClusterRoleBinding('cluster-backup-object-reader') {
  subjects_: [ sa ],
  roleRef_: role,
};

local objectDumperConfig = kube.ConfigMap('object-dumper') + namespaceMeta + {
  data: {
    'known-to-fail': std.join('\n', params.known_to_fail),
    'must-exist': std.join('\n', params.must_exist),
  },
};

local objectDumper =
  local image = params.images.object_dumper;
  local pod = backup.PreBackupPod(
    'object-dumper',
    '%s:%s' % [ image.image, image.tag ],
    '/usr/local/bin/dump-objects -sd /data',
    fileext='.tar.gz'
  ) + namespaceMeta;
  pod {
    spec+: {
      pod+: {
        spec+: {
          serviceAccountName: sa.metadata.name,
          containers: [
            pod.spec.pod.spec.containers[0] {
              env: [
                {
                  name: 'HOME',
                  value: '/home/dumper',
                },
              ],
              volumeMounts: [
                {
                  name: 'data',
                  mountPath: '/data',
                },
                {
                  name: 'home',
                  mountPath: '/home/dumper',
                },
                {
                  name: 'config',
                  mountPath: '/usr/local/share/k8s-object-dumper',
                },
              ],
            },
          ],
          volumes: [
            {
              name: 'data',
              emptyDir: {},
            },
            {
              name: 'home',
              emptyDir: {},
            },
            {
              name: 'config',
              configMap: {
                name: objectDumperConfig.metadata.name,
              },
            },
          ],
        },
      },
    },
  };

[
  namespace,
  sa,
  role,
  binding,
  objectDumperConfig,
  objectDumper,
] + schedule.Schedule('objects', params.namespace, '%d * * * *' % schedule.RandomMinute(params.namespace))
