local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

local etcdBackup =
  local image = params.images.etcd_backup;
  local pod = backup.PreBackupPod(
    'etcd-backup',
    '%s/%s:%s' % [ image.registry, image.image, image.tag ],
    'tar czf - /host/mnt/backup/*.{db,tar.gz}',
    fileext='.tar.gz'
  );
  pod {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      pod+: {
        spec+: {
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
  etcdBackup,
]
