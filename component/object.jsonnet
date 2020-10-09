local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

local namespace = {
  metadata+: { namespace: params.namespace },
};

local sa = kube.ServiceAccount('object-backup') + namespace;

local role = kube.ClusterRole('cluster-backup-object-reader') {
  rules: [
    {
      apiGroups: [ '*' ],
      resources: [ '*' ],
      verbs: [ 'view', 'list' ],
    },
  ],
};

local binding = kube.ClusterRoleBinding('cluster-backup-object-reader') {
  subjects_: [ sa ],
  roleRef_: role,
};

local objectDumper =
  local image = params.images.object_dumper;
  backup.PreBackupPod(
    'object-dumper',
    '%s:%s' % [ image.image, image.tag ],
    '/usr/local/bin/dump-objects -sd /data',
    fileext='.tar.gz'
  ) + namespace + {
    spec+: {
      pod+: {
        spec+: {
          serviceAccountName: sa.metadata.name,
        },
      },
    },
  };

[
  sa,
  role,
  binding,
  objectDumper,
]
