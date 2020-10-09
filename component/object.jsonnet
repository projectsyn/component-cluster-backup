local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

local sa = kube.ServiceAccount('object-backup') {
  metadata+: { namespace: params.namespace },
};

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

[
  sa,
  role,
  binding,
]
