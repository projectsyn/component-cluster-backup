local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

local schedule = import 'schedule.libsonnet';

local namespaceName = '%s-etcd' % params.namespace;
local privilegedNamespace = kube.Namespace(namespaceName) {
  metadata+: {
    annotations+: {
      // Jobs must be allowed on master nodes to backup etcd
      'openshift.io/node-selector': '',
    },
  },
};

local serviceAccount = kube.ServiceAccount('etcd-backup') {
  metadata+: {
    namespace: namespaceName,
  },
};

local scc = kube._Object('security.openshift.io/v1', 'SecurityContextConstraints', namespaceName) {
  allowPrivilegedContainer: true,
  allowHostNetwork: true,
  allowHostDirVolumePlugin: true,
  allowedCapabilities: null,
  allowHostPorts: false,
  allowHostPID: false,
  allowHostIPC: false,
  readOnlyRootFilesystem: true,
  requiredDropCapabilities: [],
  defaultAddCapabilities: [],
  runAsUser: {
    type: 'RunAsAny',
  },
  seLinuxContext: {
    type: 'MustRunAs',
  },
  fsGroup: {
    type: 'MustRunAs',
  },
  supplementalGroups: {
    type: 'RunAsAny',
  },
  volumes: [
    'configMap',
    'downwardAPI',
    'emptyDir',
    'hostPath',
    'projected',
    'secret',
  ],
  users: [
    'system:serviceaccount:%s:%s' % [ namespaceName, serviceAccount.metadata.name ],
  ],
};

local etcdBackup =
  local image = params.images.etcd_backup;
  local pod = backup.PreBackupPod(
    'etcd-backup',
    '%s/%s:%s' % [ image.registry, image.image, image.tag ],
    'tar czf - -C /host/mnt/backup/ .',
    fileext='.tar.gz'
  );
  pod {
    metadata+: {
      namespace: namespaceName,
    },
    spec+: {
      pod+: {
        spec+: {
          serviceAccountName: serviceAccount.metadata.name,
          initContainers: [
            kube.Container('dump-database') {
              image: '%s/%s:%s' % [ image.registry, image.image, image.tag ],
              command: [ 'chroot', '/host' ],
              args: [
                '/usr/local/bin/cluster-backup.sh',
                '/mnt/backup',
              ],
              resources: {
                limits: {
                  memory: '128Mi',
                  cpu: '500m',
                },
              },
              securityContext: {
                privileged: true,
                runAsUser: 0,
              },
              volumeMounts_: {
                host: {
                  mountPath: '/host',
                },
                backup: {
                  mountPath: '/host/mnt/backup',
                },
              },
            },
          ],
          containers: [ super.containers[0] {
            resources: {
              limits: {
                memory: '128Mi',
                cpu: '500m',
              },
            },
            volumeMounts: [
              {
                mountPath: '/host',
                name: 'host',
              },
              {
                mountPath: '/host/mnt/backup',
                name: 'backup',
              },
            ],
          } ],
          hostNetwork: true,
          volumes: [
            {
              hostPath: {
                path: '/',
                type: 'Directory',
              },
              name: 'host',
            },
            {
              emptyDir: {},
              name: 'backup',
            },
          ],
          nodeSelector: {
            'node-role.kubernetes.io/master': '',
          },
          tolerations: [
            {
              key: 'node-role.kubernetes.io/master',
              operator: 'Exists',
              effect: 'NoSchedule',
            },
          ],
        },
      },
    },
  };

[
  privilegedNamespace,
  serviceAccount,
  scc,
  etcdBackup,
] + schedule.Schedule(
  'etcd',
  namespaceName,
  '%d 3 * * *' % schedule.RandomMinute(namespaceName),
  '20 */4 * * *'
)
