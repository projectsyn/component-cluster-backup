local backup = import 'lib/backup-k8up.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.cluster_backup;

local defaultLabels(name) = {
  metadata+: {
    labels+: {
      'app.kubernetes.io/name': name,
      'app.kubernetes.io/component': 'cluster-backup',
      'app.kubernetes.io/managed-by': 'commodore',
    },
  },
};

local addDefaultLabels(objs) =
  std.map(function(obj) obj + defaultLabels(obj.metadata.name), objs);

// Define outputs below
{
  '10_object': addDefaultLabels(import 'object.jsonnet'),
  '20_etcd': addDefaultLabels(import 'etcd.jsonnet'),
}
